#include "Account.h"
#include "Browser.h"
#include "Crypto.h"
#include "Keychain.h"
#include "SyncMerge.h"

#include <QBuffer>
#include <QDir>
#include <QFile>
#include <QHostInfo>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QPainter>
#include <QPainterPath>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QSysInfo>
#include <QTcpServer>
#include <QTcpSocket>
#include <QUrlQuery>

// The f1int Supabase project. The publishable key is meant to ship inside apps: the
// database's row-level security is what keeps each account's rows to itself.
static const QString kServer = QStringLiteral("https://itepmsbnmpgsnhxinfgh.supabase.co");
static const QByteArray kPublishableKey = "sb_publishable_zhLo4nxrZRyoxSLkIG6zAA_ahp4eAsH";
static const int kLinkPort = 3000;   // the project's "site URL": where email links land (see startLinkListener)
static const QStringList kKinds = { "bookmarks", "settings", "themes", "newtab", "history" };

static QString sessionKeyName() { return QCoreApplication::applicationName() + QStringLiteral("-account-session"); }
static QString syncKeyName() { return QCoreApplication::applicationName() + QStringLiteral("-sync-key"); }

Account::Account(Browser *browser, QObject *parent)
    : QObject(parent), m_browser(browser)
{
    m_email = m_browser->setting(QStringLiteral("account/email")).toString();
    m_username = m_browser->setting(QStringLiteral("account/username")).toString();
    m_avatar = m_browser->setting(QStringLiteral("account/avatar")).toString();
    m_deviceId = m_browser->setting(QStringLiteral("account/deviceId")).toString();
    m_lastSync = m_browser->setting(QStringLiteral("sync/last")).toDateTime();

    m_autoSync.setInterval(10 * 60 * 1000);
    connect(&m_autoSync, &QTimer::timeout, this, &Account::syncNow);
    // A little while after bookmarks or settings change, sync them (if sync is on).
    m_soonSync.setSingleShot(true);
    m_soonSync.setInterval(20 * 1000);
    connect(&m_soonSync, &QTimer::timeout, this, &Account::syncNow);
    const auto soon = [this] { if (!m_syncing && m_state == QLatin1String("signedIn") && syncOn()) m_soonSync.start(); };
    connect(m_browser->library(), &Library::changed, this, soon);
    connect(m_browser, &Browser::settingChanged, this, soon);

    // Signed in last time? Pick the session back up.
    QByteArray refresh;
    if (!m_email.isEmpty() && Keychain::load(sessionKeyName(), &refresh) && !refresh.isEmpty()) {
        m_refresh = refresh;
        Keychain::load(syncKeyName(), &m_syncKey);
        m_state = QStringLiteral("signedIn");
        withFreshToken([this] { afterSignIn(false); });
    }
}

// ---------------------------------------------------------------- keys

QByteArray Account::stretch(const QString &email, const QString &password)
{
    return Crypto::deriveKey(password.toUtf8(), (QStringLiteral("f1int-account:") + email.trimmed().toLower()).toUtf8(), 600000);
}
QString Account::authSecret(const QByteArray &master)
{
    return QString::fromLatin1(Crypto::deriveKey(master, "f1int-auth", 1).toHex());
}
QByteArray Account::wrapKey(const QByteArray &master)
{
    return Crypto::deriveKey(master, "f1int-wrap", 1);
}

// ---------------------------------------------------------------- plumbing

bool Account::syncOn() const { return m_browser->setting(QStringLiteral("sync/on"), true).toBool(); }

QVariantMap Account::syncKinds() const
{
    QVariantMap out;
    const QJsonObject saved = QJsonDocument::fromJson(m_browser->setting(QStringLiteral("sync/kinds")).toString().toUtf8()).object();
    for (const QString &k : kKinds)
        out.insert(k, saved.contains(k) ? saved[k].toBool() : k != QLatin1String("history"));   // history: only if you ask
    return out;
}

void Account::setMessage(const QString &text) { m_message = text; emit changed(); }
void Account::setState(const QString &state) { m_state = state; emit changed(); }

void Account::call(const QString &method, const QString &path, const QJsonValue &body, bool authed,
                   const Reply &done, const QByteArray &prefer)
{
    QNetworkRequest req(QUrl(kServer + path));
    req.setRawHeader("apikey", kPublishableKey);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    if (authed && !m_access.isEmpty())
        req.setRawHeader("Authorization", "Bearer " + m_access);
    if (!prefer.isEmpty())
        req.setRawHeader("Prefer", prefer);
    req.setTransferTimeout(30000);
    QByteArray data;
    if (body.isObject())
        data = QJsonDocument(body.toObject()).toJson(QJsonDocument::Compact);
    else if (body.isArray())
        data = QJsonDocument(body.toArray()).toJson(QJsonDocument::Compact);
    QNetworkReply *reply = m_net.sendCustomRequest(req, method.toLatin1(), data);
    work(+1);
    connect(reply, &QNetworkReply::finished, this, [this, reply, done] {
        work(-1);
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray raw = reply->readAll();
        const QJsonDocument doc = QJsonDocument::fromJson(raw);
        QJsonValue value = doc.isObject() ? QJsonValue(doc.object()) : doc.isArray() ? QJsonValue(doc.array()) : QJsonValue(QString::fromUtf8(raw));
        bool isNumber = false;
        const qint64 number = raw.trimmed().toLongLong(&isNumber);   // functions can answer with a bare number
        if (isNumber)
            value = number;
        if (status == 0)
            value = reply->errorString();
        reply->deleteLater();
        done(status, value);
    });
}

QString Account::errorText(int status, const QJsonValue &body) const
{
    if (status == 0)
        return tr("Couldn't reach the f1int account service. Check your internet connection.");
    const QJsonObject o = body.toObject();
    const QString code = o["error_code"].toString(o["code"].toString());
    if (code == QLatin1String("invalid_credentials") || o["error"].toString() == QLatin1String("invalid_grant"))
        return tr("Wrong email or password.");
    if (code == QLatin1String("email_not_confirmed"))
        return tr("Confirm your email first: open the link we sent you (from noreply@mail.app.supabase.io; check spam). "
                  "Or paste the link here.");
    if (code == QLatin1String("over_email_send_rate_limit") || status == 429)
        return tr("Too many tries just now. Wait a little and try again.");
    if (code == QLatin1String("user_already_exists") || code == QLatin1String("email_exists"))
        return tr("There's already an account with this email. Sign in instead.");
    if (code == QLatin1String("23505"))
        return tr("That username is taken.");
    const QString text = o["msg"].toString(o["message"].toString(o["error_description"].toString()));
    return text.isEmpty() ? tr("Something went wrong (%1). Try again.").arg(status) : text;
}

void Account::takeSession(const QJsonObject &s)
{
    m_access = s["access_token"].toString().toLatin1();
    m_refresh = s["refresh_token"].toString().toLatin1();
    m_accessExpires = QDateTime::currentSecsSinceEpoch() + s["expires_in"].toInt(3600);
    const QJsonObject user = s["user"].toObject();
    if (!user.isEmpty()) {
        m_userId = user["id"].toString();
        m_email = user["email"].toString(m_email);
    }
    m_browser->setSetting(QStringLiteral("account/email"), m_email);
    Keychain::store(sessionKeyName(), m_refresh);   // never written anywhere in plain text
}

void Account::withFreshToken(const std::function<void()> &next)
{
    if (!m_access.isEmpty() && QDateTime::currentSecsSinceEpoch() < m_accessExpires - 60) {
        next();
        return;
    }
    call(QStringLiteral("POST"), QStringLiteral("/auth/v1/token?grant_type=refresh_token"),
         QJsonObject{ { "refresh_token", QString::fromLatin1(m_refresh) } }, false, [this, next](int status, const QJsonValue &body) {
        if (status == 200) {
            takeSession(body.toObject());
            next();
        } else if (status == 0) {
            m_syncStatus = QStringLiteral("error");
            m_lastSyncNote = errorText(status, body);   // offline: stay signed in, try later
            emit changed();
        } else {
            forget(tr("You've been signed out. Sign in again to keep syncing."));
        }
    });
}

void Account::forget(const QString &why)
{
    Keychain::remove(sessionKeyName());
    Keychain::remove(syncKeyName());
    Crypto::wipe(m_syncKey);
    Crypto::wipe(m_pendingMaster);
    m_access.clear();
    m_refresh.clear();
    m_userId.clear();
    m_devices.clear();
    m_autoSync.stop();
    m_soonSync.stop();
    m_syncStatus = QStringLiteral("off");
    stopLinkListener();
    m_state = QStringLiteral("signedOut");
    m_message = why;
    emit changed();
}

// ---------------------------------------------------------------- signing up and in

void Account::signUp(const QString &email, const QString &password)
{
    const QString e = email.trimmed();
    if (!e.contains(QLatin1Char('@')) || e.size() < 5)
        return setMessage(tr("Enter your email address."));
    if (password.size() < 8)
        return setMessage(tr("Use at least 8 characters for your password."));
    Crypto::wipe(m_pendingMaster);
    m_pendingMaster = stretch(e, password);
    m_email = e;
    setMessage({});
    call(QStringLiteral("POST"), QStringLiteral("/auth/v1/signup"),
         QJsonObject{ { "email", e }, { "password", authSecret(m_pendingMaster) } }, false, [this](int status, const QJsonValue &body) {
        const QJsonObject o = body.toObject();
        if (status != 200)
            return setMessage(errorText(status, body));
        if (o.contains("access_token")) {   // no email check on this project: signed in straight away
            takeSession(o);
            return afterSignIn(true);
        }
        // An existing address comes back as a user with no identities (Supabase doesn't say more).
        if (o.contains("identities") && o["identities"].toArray().isEmpty())
            return setMessage(tr("There's already an account with this email. Sign in instead."));
        m_browser->setSetting(QStringLiteral("account/email"), m_email);
        startLinkListener();
        setState(QStringLiteral("confirmEmail"));
        setMessage(tr("We sent a link to %1 from noreply@mail.app.supabase.io. Open it on this computer to finish (check spam if it isn't there in a minute).").arg(m_email));
    });
}

void Account::resendConfirmation()
{
    call(QStringLiteral("POST"), QStringLiteral("/auth/v1/resend"), QJsonObject{ { "type", "signup" }, { "email", m_email } }, false,
         [this](int status, const QJsonValue &body) {
        setMessage(status == 200 ? tr("Sent again. Check your inbox (and spam).") : errorText(status, body));
    });
}

void Account::signIn(const QString &email, const QString &password)
{
    const QString e = email.trimmed();
    if (e.isEmpty() || password.isEmpty())
        return setMessage(tr("Enter your email and password."));
    Crypto::wipe(m_pendingMaster);
    m_pendingMaster = stretch(e, password);
    m_email = e;
    setMessage({});
    call(QStringLiteral("POST"), QStringLiteral("/auth/v1/token?grant_type=password"),
         QJsonObject{ { "email", e }, { "password", authSecret(m_pendingMaster) } }, false, [this](int status, const QJsonValue &body) {
        if (status == 200) {
            takeSession(body.toObject());
            return afterSignIn(true);
        }
        if (body.toObject()["error_code"].toString() == QLatin1String("email_not_confirmed")) {
            startLinkListener();
            setState(QStringLiteral("confirmEmail"));
        }
        setMessage(errorText(status, body));
    });
}

void Account::afterSignIn(bool fresh)
{
    setState(QStringLiteral("signedIn"));
    if (fresh)
        setMessage({});
    stopLinkListener();
    loadAccountRow();
    registerDevice();
    // A new sign-in has the password at hand to open the sync key; a resumed one uses the
    // copy in the keychain.
    if (fresh || m_syncKey.isEmpty())
        unwrapOrCreateSyncKey(true);
    else if (syncOn())
        QTimer::singleShot(1500, this, &Account::syncNow);
    if (syncOn())
        m_autoSync.start();
}

void Account::unwrapOrCreateSyncKey(bool allowCreate)
{
    if (m_pendingMaster.isEmpty()) {   // resumed session but the keychain copy is gone
        setState(QStringLiteral("needsPassword"));
        return setMessage(tr("Enter your password once more to unlock sync on this computer."));
    }
    call(QStringLiteral("GET"), QStringLiteral("/rest/v1/sync_keys?select=wrapped"), {}, true, [this, allowCreate](int status, const QJsonValue &body) {
        if (status != 200)
            return setMessage(errorText(status, body));
        const QByteArray wrap = wrapKey(m_pendingMaster);
        const QJsonArray rows = body.toArray();
        if (!rows.isEmpty()) {
            QByteArray key;
            if (Crypto::open(wrap, QByteArray::fromBase64(rows[0].toObject()["wrapped"].toString().toLatin1()), "f1int-sync-key", &key)) {
                m_syncKey = key;
                Keychain::store(syncKeyName(), m_syncKey);
                Crypto::wipe(m_pendingMaster);
                if (syncOn())
                    syncNow();
                return;
            }
            if (!allowCreate)
                return setMessage(tr("Your synced data couldn't be unlocked."));
        }
        // First sign-in anywhere: make the sync key and store it, wrapped.
        m_syncKey = Crypto::randomBytes(32);
        const QString wrapped = QString::fromLatin1(Crypto::seal(wrap, m_syncKey, "f1int-sync-key").toBase64());
        call(QStringLiteral("POST"), QStringLiteral("/rest/v1/sync_keys"), QJsonObject{ { "user_id", m_userId }, { "wrapped", wrapped } }, true,
             [this](int status, const QJsonValue &body) {
            if (status >= 300)
                return setMessage(errorText(status, body));
            Keychain::store(syncKeyName(), m_syncKey);
            Crypto::wipe(m_pendingMaster);
            if (syncOn())
                syncNow();
        }, "resolution=merge-duplicates");
    });
}

void Account::signOut()
{
    if (m_access.isEmpty())
        return forget({});
    call(QStringLiteral("POST"), QStringLiteral("/auth/v1/logout"), QJsonObject(), true, [this](int, const QJsonValue &) {
        forget(tr("Signed out. Your bookmarks and settings stay on this computer."));
    });
}

// ---------------------------------------------------------------- email links

void Account::requestReset(const QString &email)
{
    const QString e = email.trimmed();
    if (!e.contains(QLatin1Char('@')))
        return setMessage(tr("Enter your email address."));
    m_email = e;
    call(QStringLiteral("POST"), QStringLiteral("/auth/v1/recover"), QJsonObject{ { "email", e } }, false, [this](int status, const QJsonValue &body) {
        if (status != 200)
            return setMessage(errorText(status, body));
        startLinkListener();
        setState(QStringLiteral("resetSent"));
        setMessage(tr("If there's an account for %1, a reset link is on its way. Open it on this computer.").arg(m_email));
    });
}

// Email links end on this project's site URL, http://localhost:3000, with the session in the
// part after "#" (which browsers never send to a server). While a link is expected, f1int
// answers on that address with a tiny page that hands the "#..." part back to f1int.
// Tokens are only trusted after Supabase confirms them and they belong to the expected email.
void Account::startLinkListener()
{
    if (m_listener)
        return;
    auto *server = new QTcpServer(this);
    if (!server->listen(QHostAddress::LocalHost, kLinkPort)) {
        server->deleteLater();   // something else uses the port: pasting the link still works
        return;
    }
    m_listener = server;
    QTimer::singleShot(60 * 60 * 1000, server, [this] { stopLinkListener(); });
    connect(server, &QTcpServer::newConnection, this, [this, server] {
        while (QTcpSocket *socket = server->nextPendingConnection()) {
            connect(socket, &QTcpSocket::readyRead, this, [this, socket] {
                const QByteArray request = socket->peek(64 * 1024);
                const int headerEnd = request.indexOf("\r\n\r\n");
                if (headerEnd < 0)
                    return;   // wait for the rest
                static const QRegularExpression lengthRx(QStringLiteral("content-length:\\s*(\\d+)"), QRegularExpression::CaseInsensitiveOption);
                const int length = lengthRx.match(QString::fromLatin1(request.left(headerEnd))).captured(1).toInt();
                if (request.size() < headerEnd + 4 + length && length < 16 * 1024)
                    return;
                socket->readAll();
                QByteArray page;
                if (request.startsWith("POST /f1int-link")) {
                    acceptLinkTokens(QString::fromLatin1(request.mid(headerEnd + 4, length)));
                    page = "ok";
                } else {
                    page = "<!doctype html><meta charset=utf-8><title>f1int</title>"
                           "<body style='font:16px system-ui;background:#131316;color:#ececf0;display:grid;place-items:center;height:90vh'>"
                           "<p id=m>Finishing up…</p><script>"
                           "const h=location.hash.slice(1),p=new URLSearchParams(h),m=document.getElementById('m');"
                           "if(p.get('error'))m.textContent='That link didn\\'t work: '+(p.get('error_description')||p.get('error'))+'. Ask f1int for a new one.';"
                           "else if(h)fetch('/f1int-link',{method:'POST',body:h}).then(()=>m.textContent='Done. Go back to f1int: you can close this tab.');"
                           "else m.textContent='Nothing to do here. Go back to f1int.';</script>";
                }
                socket->write("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Length: "
                              + QByteArray::number(page.size()) + "\r\n\r\n" + page);
                socket->disconnectFromHost();
            });
            connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
        }
    });
}

void Account::stopLinkListener()
{
    if (m_listener) {
        m_listener->close();
        m_listener->deleteLater();
    }
}

void Account::useLink(const QString &link)
{
    const QString text = link.trimmed();
    const int hash = text.indexOf(QLatin1Char('#'));
    if (hash >= 0)
        return acceptLinkTokens(text.mid(hash + 1));
    const QUrl url(text);
    if (!url.isValid() || url.host() != QUrl(kServer).host() || !url.path().startsWith(QLatin1String("/auth/v1/verify")))
        return setMessage(tr("That doesn't look like the link from f1int's email."));
    // Open the link ourselves, without following its redirect: the redirect carries the session.
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    QNetworkReply *reply = m_net.get(req);
    work(+1);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        work(-1);
        const QString location = QString::fromUtf8(reply->rawHeader("Location"));
        reply->deleteLater();
        const int h = location.indexOf(QLatin1Char('#'));
        if (h < 0)
            return setMessage(tr("That link has expired or was already used. Ask for a new one."));
        acceptLinkTokens(location.mid(h + 1));
    });
}

void Account::acceptLinkTokens(const QString &fragment)
{
    const QUrlQuery q(fragment);
    if (q.hasQueryItem(QStringLiteral("error")))
        return setMessage(tr("That link didn't work (%1). Ask for a new one.").arg(q.queryItemValue(QStringLiteral("error_description"), QUrl::FullyDecoded)));
    const QString access = q.queryItemValue(QStringLiteral("access_token"));
    const QString type = q.queryItemValue(QStringLiteral("type"));
    if (access.isEmpty())
        return;
    QJsonObject session{ { "access_token", access }, { "refresh_token", q.queryItemValue(QStringLiteral("refresh_token")) },
                         { "expires_in", q.queryItemValue(QStringLiteral("expires_in")).toInt() } };
    // Ask Supabase who this token belongs to before trusting it.
    const QByteArray previous = m_access;
    m_access = access.toLatin1();
    call(QStringLiteral("GET"), QStringLiteral("/auth/v1/user"), {}, true, [this, session, type, previous](int status, const QJsonValue &body) mutable {
        const QJsonObject user = body.toObject();
        if (status != 200 || (!m_email.isEmpty() && user["email"].toString().compare(m_email, Qt::CaseInsensitive) != 0)) {
            m_access = previous;
            return setMessage(tr("That link is for a different account, or it has expired."));
        }
        session.insert("user", user);
        takeSession(session);
        stopLinkListener();
        if (type == QLatin1String("recovery")) {
            setState(QStringLiteral("newPassword"));
            return setMessage(tr("Choose a new password."));
        }
        if (!m_pendingMaster.isEmpty())
            return afterSignIn(true);          // just signed up on this computer
        forget(tr("Email confirmed. Now sign in with your password."));   // the password is needed to set up sync
    });
}

void Account::setNewPassword(const QString &password)
{
    if (password.size() < 8)
        return setMessage(tr("Use at least 8 characters for your password."));
    Crypto::wipe(m_pendingMaster);
    m_pendingMaster = stretch(m_email, password);
    withFreshToken([this] {
        call(QStringLiteral("PUT"), QStringLiteral("/auth/v1/user"), QJsonObject{ { "password", authSecret(m_pendingMaster) } }, true,
             [this](int status, const QJsonValue &body) {
            if (status != 200)
                return setMessage(errorText(status, body));
            // Only the old password could open the old sync key, so synced data starts again
            // from this computer: the server's copy (unreadable now) is deleted.
            call(QStringLiteral("DELETE"), QStringLiteral("/rest/v1/sync_items?user_id=eq.") + m_userId, {}, true, [this](int, const QJsonValue &) {
                call(QStringLiteral("DELETE"), QStringLiteral("/rest/v1/sync_keys?user_id=eq.") + m_userId, {}, true, [this](int, const QJsonValue &) {
                    for (const QString &k : kKinds)
                        QFile::remove(baseFile(k));
                    afterSignIn(true);
                    setMessage(tr("Password changed. Your synced data is being uploaded again from this computer."));
                });
            });
        });
    });
}

void Account::changePassword(const QString &current, const QString &next)
{
    if (next.size() < 8)
        return setMessage(tr("Use at least 8 characters for the new password."));
    const QByteArray oldMaster = stretch(m_email, current);
    const QByteArray newMaster = stretch(m_email, next);
    call(QStringLiteral("POST"), QStringLiteral("/auth/v1/token?grant_type=password"),
         QJsonObject{ { "email", m_email }, { "password", authSecret(oldMaster) } }, false, [this, newMaster](int status, const QJsonValue &body) {
        if (status != 200)
            return setMessage(status == 400 ? tr("Your current password isn't right.") : errorText(status, body));
        takeSession(body.toObject());
        call(QStringLiteral("PUT"), QStringLiteral("/auth/v1/user"), QJsonObject{ { "password", authSecret(newMaster) } }, true,
             [this, newMaster](int status, const QJsonValue &body) {
            if (status != 200)
                return setMessage(errorText(status, body));
            // Same sync key, locked with the new password.
            const QString wrapped = QString::fromLatin1(Crypto::seal(wrapKey(newMaster), m_syncKey, "f1int-sync-key").toBase64());
            call(QStringLiteral("PATCH"), QStringLiteral("/rest/v1/sync_keys?user_id=eq.") + m_userId, QJsonObject{ { "wrapped", wrapped } }, true,
                 [this](int status, const QJsonValue &body) {
                setMessage(status < 300 ? tr("Password changed.") : errorText(status, body));
            });
        });
    });
}

// ---------------------------------------------------------------- profile and devices

void Account::loadAccountRow()
{
    call(QStringLiteral("GET"), QStringLiteral("/rest/v1/accounts?select=username,avatar"), {}, true, [this](int status, const QJsonValue &body) {
        if (status != 200)
            return;
        const QJsonArray rows = body.toArray();
        if (rows.isEmpty()) {   // first sign-in: make the row
            call(QStringLiteral("POST"), QStringLiteral("/rest/v1/accounts"), QJsonObject{ { "id", m_userId } }, true, [](int, const QJsonValue &) {},
                 "resolution=ignore-duplicates");
            return;
        }
        m_username = rows[0].toObject()["username"].toString();
        m_avatar = rows[0].toObject()["avatar"].toString();
        m_browser->setSetting(QStringLiteral("account/username"), m_username);
        m_browser->setSetting(QStringLiteral("account/avatar"), m_avatar);
        emit changed();
    });
}

void Account::setUsername(const QString &name)
{
    static const QRegularExpression ok(QStringLiteral("^[A-Za-z0-9_.-]{3,30}$"));
    if (!ok.match(name).hasMatch())
        return setMessage(tr("Usernames are 3–30 letters, numbers, dots, dashes or underscores."));
    withFreshToken([this, name] {
        call(QStringLiteral("PATCH"), QStringLiteral("/rest/v1/accounts?id=eq.") + m_userId,
             QJsonObject{ { "username", name }, { "updated_at", QDateTime::currentDateTimeUtc().toString(Qt::ISODate) } }, true,
             [this, name](int status, const QJsonValue &body) {
            if (status >= 300)
                return setMessage(errorText(status, body));
            m_username = name;
            m_browser->setSetting(QStringLiteral("account/username"), name);
            setMessage(tr("Username saved."));
        });
    });
}

bool Account::setAvatar(const QUrl &image)
{
    QImage img(image.toLocalFile());
    if (img.isNull()) {
        setMessage(tr("That picture couldn't be read."));
        return false;
    }
    const int side = std::min(img.width(), img.height());
    img = img.copy((img.width() - side) / 2, (img.height() - side) / 2, side, side).scaled(128, 128, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    QImage round(128, 128, QImage::Format_ARGB32_Premultiplied);
    round.fill(Qt::transparent);
    QPainter p(&round);
    p.setRenderHint(QPainter::Antialiasing);
    QPainterPath circle;
    circle.addEllipse(0, 0, 128, 128);
    p.setClipPath(circle);
    p.drawImage(0, 0, img);
    p.end();
    QByteArray png;
    QBuffer buffer(&png);
    buffer.open(QIODevice::WriteOnly);
    round.save(&buffer, "PNG");
    const QString url = QStringLiteral("data:image/png;base64,") + QString::fromLatin1(png.toBase64());
    withFreshToken([this, url] {
        call(QStringLiteral("PATCH"), QStringLiteral("/rest/v1/accounts?id=eq.") + m_userId, QJsonObject{ { "avatar", url } }, true,
             [this, url](int status, const QJsonValue &body) {
            if (status >= 300)
                return setMessage(errorText(status, body));
            m_avatar = url;
            m_browser->setSetting(QStringLiteral("account/avatar"), url);
            emit changed();
        });
    });
    return true;
}

void Account::clearAvatar()
{
    withFreshToken([this] {
        call(QStringLiteral("PATCH"), QStringLiteral("/rest/v1/accounts?id=eq.") + m_userId, QJsonObject{ { "avatar", QJsonValue::Null } }, true,
             [this](int status, const QJsonValue &) {
            if (status < 300) {
                m_avatar.clear();
                m_browser->resetSetting(QStringLiteral("account/avatar"));
                emit changed();
            }
        });
    });
}

void Account::registerDevice()
{
    call(QStringLiteral("GET"), QStringLiteral("/rest/v1/devices?select=id,name,platform,last_seen&order=last_seen.desc"), {}, true,
         [this](int status, const QJsonValue &body) {
        if (status != 200)
            return;
        bool known = false;
        for (const QJsonValue &d : body.toArray())
            known = known || d.toObject()["id"].toString() == m_deviceId;
        if (known) {
            m_devices = body.toArray().toVariantList();
            return refreshDevices();
        }
        const QString name = QHostInfo::localHostName().left(80);
        call(QStringLiteral("POST"), QStringLiteral("/rest/v1/devices"),
             QJsonObject{ { "user_id", m_userId }, { "name", name.isEmpty() ? tr("Computer") : name }, { "platform", QSysInfo::prettyProductName().left(40) } }, true,
             [this](int status, const QJsonValue &body) {
            if (status >= 300 || body.toArray().isEmpty())
                return;
            m_deviceId = body.toArray()[0].toObject()["id"].toString();
            m_browser->setSetting(QStringLiteral("account/deviceId"), m_deviceId);
            refreshDevices();
        }, "return=representation");
    });
}

void Account::refreshDevices()
{
    withFreshToken([this] {
        call(QStringLiteral("GET"), QStringLiteral("/rest/v1/devices?select=id,name,platform,last_seen&order=last_seen.desc"), {}, true,
             [this](int status, const QJsonValue &body) {
            if (status != 200)
                return;
            QVariantList list;
            bool stillHere = m_deviceId.isEmpty();
            for (const QJsonValue &d : body.toArray()) {
                QVariantMap m = d.toObject().toVariantMap();
                m["current"] = m["id"].toString() == m_deviceId;
                stillHere = stillHere || m["current"].toBool();
                list.append(m);
            }
            if (!stillHere)   // removed from the account on another computer
                return forget(tr("This computer was removed from your account. Sign in again to sync here."));
            m_devices = list;
            emit changed();
        });
    });
}

void Account::renameDevice(const QString &id, const QString &name)
{
    const QString clean = name.trimmed().left(80);
    if (clean.isEmpty())
        return;
    call(QStringLiteral("PATCH"), QStringLiteral("/rest/v1/devices?id=eq.") + QUrl::toPercentEncoding(id), QJsonObject{ { "name", clean } }, true,
         [this](int, const QJsonValue &) { refreshDevices(); });
}

void Account::removeDevice(const QString &id)
{
    if (id == m_deviceId)
        return signOut();
    call(QStringLiteral("DELETE"), QStringLiteral("/rest/v1/devices?id=eq.") + QUrl::toPercentEncoding(id), {}, true,
         [this](int status, const QJsonValue &body) {
        if (status >= 300)
            setMessage(errorText(status, body));
        refreshDevices();
    });
}

void Account::deleteAccount(const QString &password)
{
    // Ask for the password again: deleting is for good.
    call(QStringLiteral("POST"), QStringLiteral("/auth/v1/token?grant_type=password"),
         QJsonObject{ { "email", m_email }, { "password", authSecret(stretch(m_email, password)) } }, false, [this](int status, const QJsonValue &body) {
        if (status != 200)
            return setMessage(status == 400 ? tr("That password isn't right.") : errorText(status, body));
        takeSession(body.toObject());
        call(QStringLiteral("POST"), QStringLiteral("/rest/v1/rpc/delete_my_account"), QJsonObject(), true, [this](int status, const QJsonValue &body) {
            if (status >= 300)
                return setMessage(errorText(status, body));
            for (const QString &k : kKinds)
                QFile::remove(baseFile(k));
            for (const char *key : { "account/email", "account/username", "account/avatar", "account/deviceId", "sync/last" })
                m_browser->resetSetting(QString::fromLatin1(key));
            m_email.clear();
            m_username.clear();
            m_avatar.clear();
            m_deviceId.clear();
            forget(tr("Your account and everything synced were deleted. What's on this computer stays."));
        });
    });
}

// ---------------------------------------------------------------- sync

void Account::setSyncOn(bool on)
{
    m_browser->setSetting(QStringLiteral("sync/on"), on);
    if (on && m_state == QLatin1String("signedIn")) {
        m_autoSync.start();
        syncNow();
    } else {
        m_autoSync.stop();
        m_syncStatus = QStringLiteral("off");
    }
    emit changed();
}

void Account::setSyncKind(const QString &kind, bool on)
{
    if (!kKinds.contains(kind))
        return;
    QJsonObject saved = QJsonDocument::fromJson(m_browser->setting(QStringLiteral("sync/kinds")).toString().toUtf8()).object();
    saved[kind] = on;
    m_browser->setSetting(QStringLiteral("sync/kinds"), QString::fromUtf8(QJsonDocument(saved).toJson(QJsonDocument::Compact)));
    QFile::remove(baseFile(kind));   // turned back on later: start with a fresh merge
    emit changed();
}

QString Account::baseFile(const QString &kind) const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/sync/") + kind + QStringLiteral(".json");
}

QJsonObject Account::loadBase(const QString &kind, qint64 *version) const
{
    QFile f(baseFile(kind));
    if (!f.open(QIODevice::ReadOnly))
        return {};
    const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
    if (o["user"].toString() != m_userId)   // another account synced here before
        return {};
    *version = o["version"].toInteger();
    return o["items"].toObject();
}

void Account::saveBase(const QString &kind, const QJsonObject &items, qint64 version) const
{
    QDir().mkpath(QFileInfo(baseFile(kind)).path());
    QSaveFile f(baseFile(kind));
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(QJsonObject{ { "user", m_userId }, { "version", version }, { "items", items } }).toJson(QJsonDocument::Compact));
        f.commit();
    }
}

// What this computer has now, as a map, for one kind of data.
QJsonObject Account::localItems(const QString &kind) const
{
    QJsonObject items;
    if (kind == QLatin1String("bookmarks")) {
        for (const QVariant &v : m_browser->library()->bookmarks())
            items.insert(v.toMap()["url"].toString(), QJsonObject{ { "t", v.toMap()["title"].toString() } });
    } else if (kind == QLatin1String("history")) {
        for (const QVariant &v : m_browser->library()->history({}, 5000)) {
            const QVariantMap h = v.toMap();
            items.insert(h["url"].toString(), QJsonObject{ { "t", h["title"].toString() }, { "v", h["visits"].toInt() }, { "l", h["last_visit"].toLongLong() } });
        }
    } else if (kind == QLatin1String("settings")) {
        const QVariantMap all = m_browser->settingsForBackup();
        for (auto it = all.begin(); it != all.end(); ++it)
            if (it.key() != QLatin1String("appearance/saved") && it.key() != QLatin1String("newtab/config"))
                items.insert(it.key(), it.value().toString());   // as text: the same on every system
    } else if (kind == QLatin1String("themes")) {
        for (const QJsonValue &t : QJsonDocument::fromJson(m_browser->setting(QStringLiteral("appearance/saved"), QStringLiteral("[]")).toString().toUtf8()).array())
            if (!t.toObject()["id"].toString().isEmpty())
                items.insert(t.toObject()["id"].toString(), t);
    } else if (kind == QLatin1String("newtab")) {
        const QString config = m_browser->setting(QStringLiteral("newtab/config")).toString();
        if (!config.isEmpty())
            items.insert(QStringLiteral("config"), config);
    }
    return items;
}

// Make this computer match `items` (it had `before`).
void Account::applyItems(const QString &kind, const QJsonObject &items, const QJsonObject &before)
{
    Library *lib = m_browser->library();
    if (kind == QLatin1String("bookmarks")) {
        for (const QString &url : before.keys())
            if (!items.contains(url))
                lib->removeBookmark(QUrl(url));
        for (auto it = items.begin(); it != items.end(); ++it) {
            const QString title = it.value().toObject()["t"].toString();
            if (!before.contains(it.key()))
                lib->addBookmark(QUrl(it.key()), title);
            else if (before[it.key()].toObject()["t"].toString() != title)
                lib->renameBookmark(QUrl(it.key()), title);
        }
    } else if (kind == QLatin1String("history")) {
        for (const QString &url : before.keys())
            if (!items.contains(url))
                lib->removeHistory(QUrl(url));
        QVariantList add;
        for (auto it = items.begin(); it != items.end(); ++it)
            if (before.value(it.key()) != it.value()) {
                const QJsonObject h = it.value().toObject();
                add.append(QVariantMap{ { "url", it.key() }, { "title", h["t"].toString() }, { "visits", h["v"].toInt() }, { "last_visit", h["l"].toInteger() } });
            }
        if (!add.isEmpty())
            lib->addHistory(add);
    } else if (kind == QLatin1String("settings")) {
        m_browser->restoreSettings(items.toVariantMap());
        for (const QString &key : before.keys())
            if (!items.contains(key))
                m_browser->resetSetting(key);
    } else if (kind == QLatin1String("themes")) {
        QJsonArray list;
        for (const QJsonValue &t : items)
            list.append(t);
        m_browser->setSetting(QStringLiteral("appearance/saved"), QString::fromUtf8(QJsonDocument(list).toJson(QJsonDocument::Compact)));
    } else if (kind == QLatin1String("newtab")) {
        if (items.contains(QStringLiteral("config")))
            m_browser->setSetting(QStringLiteral("newtab/config"), items["config"].toString());
        else
            m_browser->resetSetting(QStringLiteral("newtab/config"));
    }
}

void Account::syncNow()
{
    if (m_state != QLatin1String("signedIn") || m_syncKey.isEmpty() || m_syncing || !syncOn())
        return;
    QStringList queue;
    const QVariantMap kinds = syncKinds();
    for (const QString &k : kKinds)
        if (kinds[k].toBool())
            queue.append(k);
    if (queue.isEmpty())
        return;
    m_syncing = true;
    m_syncConflicts.clear();
    m_syncStatus = QStringLiteral("syncing");
    emit changed();
    withFreshToken([this, queue] {
        // Say this computer was here; that also tells us if it was removed elsewhere.
        if (!m_deviceId.isEmpty())
            call(QStringLiteral("PATCH"), QStringLiteral("/rest/v1/devices?id=eq.") + m_deviceId,
                 QJsonObject{ { "last_seen", QDateTime::currentDateTimeUtc().toString(Qt::ISODate) } }, true, [](int, const QJsonValue &) {});
        refreshDevices();
        syncKind(queue, 0);
    });
}

void Account::syncKind(const QStringList &queue, int attempt)
{
    if (m_state != QLatin1String("signedIn"))
        return finishSync(false);
    const QString kind = queue.first();
    const QByteArray context = (QStringLiteral("f1int-sync/") + m_userId + QLatin1Char('/') + kind).toUtf8();
    call(QStringLiteral("GET"), QStringLiteral("/rest/v1/sync_items?select=data,version&kind=eq.") + kind, {}, true,
         [this, queue, attempt, kind, context](int status, const QJsonValue &body) {
        if (status != 200) {
            m_lastSyncNote = errorText(status, body);
            return finishSync(false);
        }
        const QJsonArray rows = body.toArray();
        const qint64 remoteVersion = rows.isEmpty() ? 0 : rows[0].toObject()["version"].toInteger();
        QJsonObject remote;
        if (!rows.isEmpty()) {
            QByteArray plain;
            if (!Crypto::open(m_syncKey, QByteArray::fromBase64(rows[0].toObject()["data"].toString().toLatin1()), context, &plain)) {
                // The sync key changed (password reset on another computer).
                Keychain::remove(syncKeyName());
                Crypto::wipe(m_syncKey);
                m_syncing = false;
                setState(QStringLiteral("needsPassword"));
                return setMessage(tr("Your password was changed on another computer. Enter the new one to keep syncing."));
            }
            remote = QJsonDocument::fromJson(qUncompress(plain)).object()["items"].toObject();
        }
        qint64 baseVersion = 0;
        const QJsonObject base = loadBase(kind, &baseVersion);
        const QJsonObject local = localItems(kind);
        QStringList conflicts;
        QJsonObject merged = SyncMerge::merge(base, local, remote, true, &conflicts);
        if (kind == QLatin1String("history")) {   // visits from both computers count
            for (const QString &url : conflicts) {
                const QJsonObject l = local[url].toObject(), r = remote[url].toObject();
                if (!l.isEmpty() && !r.isEmpty())
                    merged[url] = QJsonObject{ { "t", r["t"] }, { "v", std::max(l["v"].toInt(), r["v"].toInt()) },
                                              { "l", std::max(l["l"].toInteger(), r["l"].toInteger()) } };
            }
        } else {
            for (const QString &c : conflicts)
                m_syncConflicts.append(kind == QLatin1String("settings") ? c : kind);
        }
        if (merged != local) {
            applyItems(kind, merged, local);
            m_soonSync.stop();   // applying isn't a change of ours to send back
        }
        const auto next = [this, queue] {
            QStringList rest = queue.mid(1);
            rest.isEmpty() ? finishSync(true) : syncKind(rest, 0);
        };
        if (!rows.isEmpty() && merged == remote) {
            saveBase(kind, merged, remoteVersion);
            return next();
        }
        // Upload: compressed, then encrypted with the sync key.
        const QByteArray payload = qCompress(QJsonDocument(QJsonObject{ { "v", 1 }, { "items", merged } }).toJson(QJsonDocument::Compact));
        const QString data = QString::fromLatin1(Crypto::seal(m_syncKey, payload, context).toBase64());
        if (data.size() > 4900000) {
            m_lastSyncNote = tr("Too much %1 to sync.").arg(kind);
            saveBase(kind, merged, remoteVersion);
            return next();
        }
        call(QStringLiteral("POST"), QStringLiteral("/rest/v1/rpc/push_sync_item"),
             QJsonObject{ { "p_kind", kind }, { "p_data", data }, { "p_expected", remoteVersion },
                          { "p_device", m_deviceId.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(m_deviceId) } }, true,
             [this, queue, attempt, kind, merged, next](int status, const QJsonValue &body) {
            const qint64 version = body.toInteger(-2);
            if (status != 200) {
                m_lastSyncNote = errorText(status, body);
                return finishSync(false);
            }
            if (version == -1) {   // another computer saved first: merge again with theirs
                if (attempt < 3)
                    return syncKind(queue, attempt + 1);
                m_lastSyncNote = tr("Another computer kept changing %1; trying again later.").arg(kind);
                return finishSync(false);
            }
            saveBase(kind, merged, version);
            next();
        });
    });
}

void Account::finishSync(bool ok)
{
    m_syncing = false;
    m_syncStatus = ok ? QStringLiteral("idle") : QStringLiteral("error");
    if (ok) {
        m_lastSync = QDateTime::currentDateTime();
        m_browser->setSetting(QStringLiteral("sync/last"), m_lastSync);
        m_syncConflicts.removeDuplicates();
        m_lastSyncNote = m_syncConflicts.isEmpty() ? QString()
            : tr("Changed on two computers: %1. The other computer's version was kept.").arg(m_syncConflicts.mid(0, 5).join(QStringLiteral(", ")));
    }
    m_soonSync.stop();   // (saving the time above is a setting change too)
    emit changed();
}
