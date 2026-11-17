#include "PasswordVault.h"
#include "Crypto.h"
#include "Keychain.h"

#include <QClipboard>
#include <QDateTime>
#include <QFile>
#include <QGuiApplication>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QRandomGenerator>
#include <QSaveFile>
#include <QStringDecoder>
#include <QUuid>
#include <algorithm>

static const QByteArray KeyContext = "f1int-vault-key-v1";    // binds each encrypted blob to its purpose
static const QByteArray DataContext = "f1int-vault-data-v1";
static constexpr int Iterations = 600000;                      // OWASP 2023 advice for PBKDF2-SHA256

PasswordVault::PasswordVault(const QString &filePath, const QString &keychainName, QObject *parent)
    : QObject(parent), m_path(filePath), m_keychainName(keychainName)
{
    readHeader();
    m_autoLock.setSingleShot(true);
    connect(&m_autoLock, &QTimer::timeout, this, &PasswordVault::lock);
}

PasswordVault::~PasswordVault()
{
    lock();
}

QString PasswordVault::state() const
{
    if (m_header.isEmpty())
        return QStringLiteral("none");
    return m_key.isEmpty() ? QStringLiteral("locked") : QStringLiteral("unlocked");
}

bool PasswordVault::readHeader()
{
    QFile f(m_path);
    if (!f.open(QIODevice::ReadOnly))
        return false;
    m_header = QJsonDocument::fromJson(f.readAll()).object();
    return !m_header.isEmpty();
}

// ---------------- locking ----------------

bool PasswordVault::setUp(const QString &master, bool deviceUnlock)
{
    if (!m_header.isEmpty() || master.size() < 8)
        return false;
    QByteArray vaultKey = Crypto::randomBytes(32);
    const QByteArray salt = Crypto::randomBytes(16);
    QByteArray passwordKey = Crypto::deriveKey(master.toUtf8(), salt, Iterations);
    m_header = QJsonObject{ { "version", 1 }, { "kdf", "pbkdf2-sha256" }, { "iterations", Iterations },
                            { "salt", QString::fromLatin1(salt.toBase64()) },
                            { "wrapped", QString::fromLatin1(Crypto::seal(passwordKey, vaultKey, KeyContext).toBase64()) },
                            { "device", deviceUnlock && Keychain::store(m_keychainName, vaultKey) } };
    Crypto::wipe(passwordKey);
    m_key = vaultKey;
    Crypto::wipe(vaultKey);
    m_entries.clear();
    markVerified();
    touch();
    return write();
}

bool PasswordVault::unlock(const QString &master)
{
    if (m_header.isEmpty() && !readHeader())
        return false;
    const QByteArray salt = QByteArray::fromBase64(m_header["salt"].toString().toLatin1());
    QByteArray passwordKey = Crypto::deriveKey(master.toUtf8(), salt, m_header["iterations"].toInt(Iterations));
    QByteArray vaultKey;
    const bool ok = Crypto::open(passwordKey, QByteArray::fromBase64(m_header["wrapped"].toString().toLatin1()), KeyContext, &vaultKey);
    Crypto::wipe(passwordKey);
    return ok && openWith(vaultKey);
}

bool PasswordVault::unlockWithKeychain()
{
    QByteArray vaultKey;
    return deviceUnlock() && Keychain::load(m_keychainName, &vaultKey) && openWith(vaultKey);
}

bool PasswordVault::openWith(QByteArray vaultKey)
{
    QByteArray json;
    const QByteArray sealed = QByteArray::fromBase64(m_header["data"].toString().toLatin1());
    if (!Crypto::open(vaultKey, sealed, DataContext, &json)) {
        Crypto::wipe(vaultKey);
        return false;
    }
    m_entries.clear();
    for (const QJsonValue &v : QJsonDocument::fromJson(json).array()) {
        const QJsonObject o = v.toObject();
        m_entries.append({ o["id"].toString(), o["origin"].toString(), o["username"].toString(), o["password"].toString(),
                           o["note"].toString(), qint64(o["created"].toDouble()), qint64(o["updated"].toDouble()) });
    }
    Crypto::wipe(json);
    m_key = vaultKey;
    Crypto::wipe(vaultKey);
    markVerified();
    touch();
    ++m_revision;
    emit changed();
    return true;
}

void PasswordVault::lock()
{
    for (Entry &e : m_entries)
        e.password.fill(QChar(0));   // overwrite before freeing
    m_entries.clear();
    Crypto::wipe(m_key);
    m_verifiedAt = 0;
    m_autoLock.stop();
    ++m_revision;
    emit changed();
}

bool PasswordVault::verify(const QString &master)
{
    const QByteArray salt = QByteArray::fromBase64(m_header["salt"].toString().toLatin1());
    QByteArray passwordKey = Crypto::deriveKey(master.toUtf8(), salt, m_header["iterations"].toInt(Iterations));
    QByteArray vaultKey;
    const bool ok = Crypto::open(passwordKey, QByteArray::fromBase64(m_header["wrapped"].toString().toLatin1()), KeyContext, &vaultKey);
    Crypto::wipe(passwordKey);
    Crypto::wipe(vaultKey);
    if (ok)
        markVerified();
    return ok;
}

void PasswordVault::markVerified()
{
    m_verifiedAt = QDateTime::currentMSecsSinceEpoch();
}

bool PasswordVault::recentlyVerified() const
{
    return !m_key.isEmpty() && QDateTime::currentMSecsSinceEpoch() - m_verifiedAt < 60 * 1000;
}

void PasswordVault::setDeviceUnlock(bool on)
{
    if (m_key.isEmpty())
        return;
    if (on)
        on = Keychain::store(m_keychainName, m_key);
    else
        Keychain::remove(m_keychainName);
    m_header["device"] = on;
    write();
}

void PasswordVault::forgetVault()
{
    lock();
    Keychain::remove(m_keychainName);
    QFile::remove(m_path);
    m_header = {};
    ++m_revision;
    emit changed();
}

void PasswordVault::touch()
{
    if (m_autoLockMinutes > 0)
        m_autoLock.start(m_autoLockMinutes * 60 * 1000);
}

bool PasswordVault::write()
{
    if (m_key.isEmpty())
        return false;
    QJsonArray list;
    for (const Entry &e : m_entries)
        list.append(QJsonObject{ { "id", e.id }, { "origin", e.origin }, { "username", e.username }, { "password", e.password },
                                 { "note", e.note }, { "created", double(e.created) }, { "updated", double(e.updated) } });
    QByteArray json = QJsonDocument(list).toJson(QJsonDocument::Compact);
    m_header["data"] = QString::fromLatin1(Crypto::seal(m_key, json, DataContext).toBase64());
    Crypto::wipe(json);

    QSaveFile f(m_path);   // write to a temp file, then swap: never a half-written vault
    const bool ok = f.open(QIODevice::WriteOnly) && f.write(QJsonDocument(m_header).toJson()) > 0 && f.commit();
    ++m_revision;
    emit changed();
    return ok;
}

// ---------------- logins ----------------

QString PasswordVault::originOf(const QUrl &url)
{
    if (url.scheme() != QLatin1String("http") && url.scheme() != QLatin1String("https"))   // "android://<key hash>@com.example.app" -> "android://com.example.app"
        return url.toString(QUrl::RemovePath | QUrl::RemoveQuery | QUrl::RemoveFragment | QUrl::RemoveUserInfo);
    return url.adjusted(QUrl::RemovePath | QUrl::RemoveQuery | QUrl::RemoveFragment | QUrl::RemoveUserInfo).toString().toLower();
}

bool PasswordVault::sameSite(const QString &origin, const QUrl &page)
{
    const QUrl saved(origin);
    const auto bare = [](QString h) { return h.startsWith(QLatin1String("www.")) ? h.mid(4) : h; };
    if (bare(saved.host().toLower()) != bare(page.host().toLower()))
        return false;
    // A password saved on a secure (https) page is never offered to an insecure (http) one.
    return !(saved.scheme() == QLatin1String("https") && page.scheme() != QLatin1String("https"));
}

const PasswordVault::Entry *PasswordVault::find(const QString &id) const
{
    for (const Entry &e : m_entries)
        if (e.id == id)
            return &e;
    return nullptr;
}

QVariantList PasswordVault::loginsFor(const QUrl &page) const
{
    QVariantList out;
    for (const Entry &e : m_entries)
        if (sameSite(e.origin, page))
            out.append(QVariantMap{ { "id", e.id }, { "username", e.username } });
    return out;
}

QVariantList PasswordVault::entries(const QString &filter) const
{
    QHash<QString, int> uses;   // how many logins share each password
    for (const Entry &e : m_entries)
        ++uses[e.password];
    QVariantList out;
    for (const Entry &e : m_entries) {
        if (!filter.isEmpty() && !e.origin.contains(filter, Qt::CaseInsensitive) && !e.username.contains(filter, Qt::CaseInsensitive))
            continue;
        out.append(QVariantMap{ { "id", e.id }, { "origin", e.origin }, { "username", e.username },
                                { "weak", isWeak(e.password) }, { "reused", uses.value(e.password) > 1 },
                                { "updated", double(e.updated) } });
    }
    std::sort(out.begin(), out.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap()["origin"].toString() < b.toMap()["origin"].toString();
    });
    return out;
}

QString PasswordVault::password(const QString &id) const
{
    const Entry *e = find(id);
    return e ? e->password : QString();
}

QString PasswordVault::reveal(const QString &id) const
{
    return recentlyVerified() ? password(id) : QString();
}

QString PasswordVault::saveKind(const QUrl &page, const QString &username, const QString &password) const
{
    for (const Entry &e : m_entries)
        if (sameSite(e.origin, page) && e.username == username)
            return e.password == password ? QStringLiteral("same") : QStringLiteral("update");
    return QStringLiteral("new");
}

QString PasswordVault::save(const QUrl &page, const QString &username, const QString &password)
{
    if (m_key.isEmpty() || password.isEmpty())
        return {};
    touch();
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    for (Entry &e : m_entries)
        if (sameSite(e.origin, page) && e.username == username) {
            e.password = password;
            e.updated = now;
            write();
            return e.id;
        }
    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_entries.append({ id, originOf(page), username, password, {}, now, now });
    write();
    return id;
}

void PasswordVault::edit(const QString &id, const QString &origin, const QString &username, const QString &password)
{
    for (Entry &e : m_entries)
        if (e.id == id) {
            if (!origin.isEmpty()) e.origin = originOf(QUrl::fromUserInput(origin));
            e.username = username;
            if (!password.isEmpty()) e.password = password;
            e.updated = QDateTime::currentMSecsSinceEpoch();
        }
    touch();
    write();
}

void PasswordVault::remove(const QString &id)
{
    m_entries.removeIf([&](const Entry &e) { return e.id == id; });
    touch();
    write();
}

void PasswordVault::copy(const QString &id, const QString &field)
{
    const Entry *e = find(id);
    if (!e || !qGuiApp)
        return;
    const QString text = field == QLatin1String("username") ? e->username : e->password;
    qGuiApp->clipboard()->setText(text);
    touch();
    // Clear it again after 30 seconds, unless something else was copied since.
    QTimer::singleShot(30000, qGuiApp, [text] {
        if (qGuiApp->clipboard()->text() == text)
            qGuiApp->clipboard()->clear();
    });
}

QVariantMap PasswordVault::health() const
{
    int weak = 0, reused = 0;
    for (const QVariant &v : entries()) {
        weak += v.toMap()["weak"].toBool();
        reused += v.toMap()["reused"].toBool();
    }
    return { { "weak", weak }, { "reused", reused } };
}

// ---------------- import / export ----------------

QList<QStringList> PasswordVault::parseCsv(const QByteArray &data)
{
    // RFC 4180: fields may be "quoted", quotes inside are doubled, and quoted fields
    // may contain commas and line breaks. A quote in the middle of an unquoted field
    // is kept as a character (some tools write passwords like ab"c without quoting).
    QList<QStringList> rows;
    QStringList row;
    QString field;
    bool quoted = false, fieldStart = true;
    // UTF-8 unless a byte-order mark says otherwise (UTF-16 from Notepad); the mark itself is dropped.
    const QString text = QStringDecoder(QStringConverter::encodingForData(data).value_or(QStringConverter::Utf8)).decode(data);
    for (int i = 0; i < text.size(); ++i) {
        const QChar c = text[i];
        if (quoted) {
            if (c == QLatin1Char('"')) {
                if (i + 1 < text.size() && text[i + 1] == QLatin1Char('"')) { field += c; ++i; }
                else quoted = false;
            } else field += c;
        } else if (c == QLatin1Char('"') && fieldStart) { quoted = true; fieldStart = false; }
        else if (c == QLatin1Char(',')) { row << field; field.clear(); fieldStart = true; }
        else if (c == QLatin1Char('\n') || c == QLatin1Char('\r')) {
            if (c == QLatin1Char('\r') && i + 1 < text.size() && text[i + 1] == QLatin1Char('\n')) ++i;
            row << field; field.clear(); fieldStart = true;
            if (!(row.size() == 1 && row[0].isEmpty())) rows << row;
            row.clear();
        } else { field += c; fieldStart = false; }
    }
    if (!field.isEmpty() || !row.isEmpty()) { row << field; rows << row; }
    return rows;
}

QVariantMap PasswordVault::importCsv(const QUrl &file)
{
    int imported = 0, skipped = 0, duplicates = 0;
    const auto result = [&](const QString &error) {
        return QVariantMap{ { "imported", imported }, { "skipped", skipped }, { "duplicates", duplicates }, { "error", error } };
    };
    m_lastImport.clear();
    if (m_key.isEmpty())
        return result(m_header.isEmpty() ? tr("Create the password vault first, then import.") : tr("Unlock your passwords first, then import."));
    const QString path = file.isLocalFile() ? file.toLocalFile() : file.toString();
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return result(tr("Couldn't open that file: %1").arg(f.errorString()));
    if (f.size() > 64 * 1024 * 1024)
        return result(tr("That file is far too big to be a password export."));
    QByteArray data = f.readAll();
    const QList<QStringList> rows = parseCsv(data);
    Crypto::wipe(data);
    // Find the columns by name. Chrome / Edge / Google: name,url,username,password,note. Firefox:
    // "url","username","password",... Safari: Title,URL,Username,Password,Notes,OTPAuth. 1Password:
    // Title,Url,Username,Password,... Bitwarden: login_uri,login_username,login_password. LastPass:
    // url,username,password,totp,extra,...
    const QStringList head = [&] { QStringList h; for (const QString &s : rows.value(0)) h << s.trimmed().toLower(); return h; }();
    const auto col = [&](std::initializer_list<const char *> names) {
        for (const char *n : names) { const int i = int(head.indexOf(QLatin1String(n))); if (i >= 0) return i; }
        return -1;
    };
    const int url = col({ "url", "login_uri", "website", "origin", "uri" });
    const int user = col({ "username", "login_username", "login", "user", "email" });
    const int pass = col({ "password", "login_password" });
    const int note = col({ "note", "notes", "extra" });
    if (url < 0 || pass < 0)
        return result(tr("That file doesn't look like a password export (it has no url and password columns)."));

    // The logins already saved, by site and username, so even a big import stays quick.
    const auto key = [](const QUrl &u, const QString &username) {
        const QString host = u.host().toLower();
        return (host.startsWith(QLatin1String("www.")) ? host.mid(4) : host) + QLatin1Char('\n') + username;
    };
    QHash<QString, QList<int>> known;
    for (int i = 0; i < m_entries.size(); ++i)
        known[key(QUrl(m_entries[i].origin), m_entries[i].username)].append(i);

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const auto cell = [](const QStringList &row, int i) { return i >= 0 && i < row.size() ? row[i] : QString(); };
    for (int r = 1; r < rows.size(); ++r) {
        const QStringList &row = rows[r];
        const QString password = cell(row, pass);
        // Bitwarden puts all of a login's addresses in one cell: the first one counts. No scheme = https.
        QString address = cell(row, url).section(QLatin1Char(','), 0, 0).trimmed();
        if (!address.isEmpty() && !address.contains(QLatin1String("://")))
            address.prepend(QLatin1String("https://"));
        const QUrl page(address);
        if (password.isEmpty() || page.host().isEmpty()) {
            ++skipped;   // e.g. a site you told the browser never to save, or a secure note
            continue;
        }
        const QString username = cell(row, user);
        QList<int> &same = known[key(page, username)];
        const auto it = std::find_if(same.cbegin(), same.cend(), [&](int i) { return sameSite(m_entries[i].origin, page); });
        if (it == same.cend()) {
            same.append(int(m_entries.size()));
            m_entries.append({ QUuid::createUuid().toString(QUuid::WithoutBraces), originOf(page), username, password,
                               cell(row, note), now, now });
            ++imported;
        } else if (m_entries[*it].password == password) {
            ++duplicates;
        } else {   // same login, another password: the imported one is taken
            m_entries[*it].password = password;
            m_entries[*it].updated = now;
            ++imported;
        }
    }
    m_lastImport = path;
    touch();
    if (imported > 0)
        write();
    return result({});
}

bool PasswordVault::deleteImportedFile()
{
    // Only on request, and only the file just imported: it holds every password in plain text.
    const bool ok = !m_lastImport.isEmpty() && QFile::remove(m_lastImport);
    m_lastImport.clear();
    return ok;
}

bool PasswordVault::exportCsv(const QUrl &file) const
{
    if (m_key.isEmpty())
        return false;
    const auto quote = [](QString s) { return QLatin1Char('"') + s.replace(QLatin1Char('"'), QLatin1String("\"\"")) + QLatin1Char('"'); };
    QByteArray out = "name,url,username,password,note\n";   // same columns as Chrome / Google
    for (const Entry &e : m_entries)
        out += (quote(QUrl(e.origin).host()) + QLatin1Char(',') + quote(e.origin) + QLatin1Char(',') + quote(e.username) + QLatin1Char(',')
                + quote(e.password) + QLatin1Char(',') + quote(e.note) + QLatin1Char('\n')).toUtf8();
    QSaveFile f(file.isLocalFile() ? file.toLocalFile() : file.toString());
    const bool ok = f.open(QIODevice::WriteOnly) && f.write(out) == out.size() && f.commit();
    Crypto::wipe(out);
    return ok;
}

// ---------------- helpers ----------------

QString PasswordVault::generate(int length)
{
    // Letters, digits and symbols, minus look-alikes (I l 1 O 0) so it can be read out.
    static const QString lower = QStringLiteral("abcdefghijkmnopqrstuvwxyz");
    static const QString upper = QStringLiteral("ABCDEFGHJKLMNPQRSTUVWXYZ");
    static const QString digits = QStringLiteral("23456789");
    static const QString symbols = QStringLiteral("-_!@#$%^&*+=?");
    const QString all = lower + upper + digits + symbols;
    length = qBound(12, length, 64);
    for (;;) {   // retry until it has every kind of character (happens almost immediately)
        QString p;
        for (int i = 0; i < length; ++i)
            p += all[int(QRandomGenerator::system()->bounded(int(all.size())))];
        const auto has = [&](const QString &set) { for (QChar c : p) if (set.contains(c)) return true; return false; };
        if (has(lower) && has(upper) && has(digits) && has(symbols))
            return p;
    }
}

bool PasswordVault::isWeak(const QString &password)
{
    // Offline check only: length, variety, and a short list of very common passwords.
    static const QStringList common = {
        "password", "123456", "123456789", "12345678", "12345", "qwerty", "abc123", "password1", "111111",
        "123123", "letmein", "welcome", "monkey", "dragon", "iloveyou", "admin", "football", "baseball",
        "sunshine", "princess", "qwerty123", "1q2w3e4r", "passw0rd", "starwars", "superman", "trustno1",
        "000000", "654321", "master", "hello", "freedom", "whatever", "qazwsx", "login", "zaq12wsx" };
    if (password.size() < 8 || common.contains(password.toLower()))
        return true;
    int kinds = 0;
    bool lower = false, upper = false, digit = false, other = false;
    for (QChar c : password) {
        if (c.isLower()) lower = true;
        else if (c.isUpper()) upper = true;
        else if (c.isDigit()) digit = true;
        else other = true;
    }
    kinds = lower + upper + digit + other;
    if (password.count(password[0]) == password.size())
        return true;   // "aaaaaaaaaa"
    return password.size() < 12 && kinds < 3;
}
