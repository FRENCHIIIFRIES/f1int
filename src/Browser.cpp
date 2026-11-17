#include "Browser.h"
#include "DeviceAuth.h"
#include "MemoryStats.h"
#include "UrlInput.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QGuiApplication>
#include <QStyleHints>
#include <QQuickWindow>
#include <QUuid>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QQmlApplicationEngine>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QWebEngineCookieStore>
#ifdef Q_OS_WIN
#define NOMINMAX   // stop windows.h from defining min/max macros that clash with Qt
#include <windows.h>
#include <dwmapi.h>   // window backdrop (frosted glass)
#endif

Browser::Browser(QObject *parent)
    : QObject(parent),
      m_profile(new QQuickWebEngineProfile(this)),
      m_adBlocker(new AdBlocker(this)),
      m_dataDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation))
{
    QDir().mkpath(m_dataDir);
    m_library = new Library(m_dataDir + QStringLiteral("/library.db"), this);
    // Passwords: test runs ("f1int-test") get their own keychain entry, never the real one.
    m_vault = new PasswordVault(m_dataDir + QStringLiteral("/passwords.vault"),
                                QCoreApplication::applicationName() + QStringLiteral("-vault-key"), this);
    m_vault->setProperty("autoLockMinutes", setting(QStringLiteral("passwords/autoLockMinutes"), 15).toInt());
    m_nonce = QString::fromLatin1(QUuid::createUuid().toRfc4122().toHex());   // new secret every start

    // One shared profile for all normal tabs, saved on disk (cookies, cache, site logins).
    // A named profile is saved; an unnamed one is thrown away on exit (used for incognito).
    m_profile->setStorageName(QStringLiteral("Default"));
    m_profile->setOffTheRecord(false);
    setUpProfile(m_profile);
    applyColorScheme();

    m_adBlocker->enabled = setting(QStringLiteral("privacy/adblock"), true).toBool();
    connect(m_adBlocker, &AdBlocker::blocked, this, &Browser::blockedChanged);
    connect(m_adBlocker, &AdBlocker::activity, this, &Browser::siteActivity);
    loadFilterLists();

    // Session restore: windows saved last time (unless the user turned it off).
    if (setting(QStringLiteral("startup/restore"), true).toBool()) {
        QFile f(m_dataDir + QStringLiteral("/session.json"));
        if (f.open(QIODevice::ReadOnly))
            for (const QJsonValue &w : QJsonDocument::fromJson(f.readAll())["windows"].toArray())
                if (!w["tabs"].toArray().isEmpty())
                    m_pendingRestore.append(w.toObject());
    }
    // Tabs are saved shortly after every change, so a crash loses at most ~1 second.
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(1000);
    connect(&m_saveTimer, &QTimer::timeout, this, &Browser::writeSession);

    connect(qApp, &QCoreApplication::aboutToQuit, this, [this] {
        if (setting(QStringLiteral("privacy/clearOnExit"), false).toBool())
            clearBrowsingData();
    });
}

void Browser::setUpProfile(QQuickWebEngineProfile *profile)
{
    profile->setUrlRequestInterceptor(m_adBlocker);
    // The default user agent ends in "QtWebEngine/6.x Chrome/..."; some sites (notably
    // Google sign-in) refuse "embedded" browsers that announce QtWebEngine. Drop that word.
    static const QRegularExpression qtToken(QStringLiteral(" QtWebEngine/\\S+"));
    profile->setHttpUserAgent(profile->httpUserAgent().remove(qtToken));
}

QUrl Browser::homeUrl() const
{
    return setting(QStringLiteral("home/url"), QStringLiteral("https://www.google.com")).toUrl();
}

bool Browser::reduceMotion() const
{
#ifdef Q_OS_WIN
    // Settings > Accessibility > Visual effects > "Animation effects"
    BOOL animations = TRUE;
    SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &animations, 0);
    return !animations;
#else
    return false;   // macOS check comes with the Mac polish pass
#endif
}

QVariantList Browser::searchEngines() const
{
    const auto engine = [](const char *name, const char *search) {
        return QVariantMap{ { "name", QString::fromLatin1(name) }, { "template", QString::fromLatin1(search) } };
    };
    return { engine("Google", "https://www.google.com/search?q=%s"),
             engine("DuckDuckGo", "https://duckduckgo.com/?q=%s"),
             engine("Bing", "https://www.bing.com/search?q=%s"),
             engine("Brave Search", "https://search.brave.com/search?q=%s"),
             engine("Ecosia", "https://www.ecosia.org/search?q=%s"),
             engine("Startpage", "https://www.startpage.com/do/search?q=%s") };
}

QUrl Browser::uiTestScript() const
{
    const QString path = qEnvironmentVariable("F1INT_UI_TEST");
    return path.isEmpty() ? QUrl() : QUrl::fromLocalFile(path);
}

QUrl Browser::urlFromInput(const QString &text) const
{
    const QString search = setting(QStringLiteral("search/template"),
                                   QStringLiteral("https://www.google.com/search?q=%s")).toString();
    return ::urlFromInput(text, search);
}

QVariant Browser::setting(const QString &key, const QVariant &fallback) const
{
    const QVariant v = m_settings.value(key, fallback);
    // The Windows registry hands booleans back as the text "true"/"false".
    if (fallback.typeId() == QMetaType::Bool)
        return v.toString() == QLatin1String("true") || v.toBool();
    return v;
}

void Browser::setSetting(const QString &key, const QVariant &value)
{
    m_settings.setValue(key, value);
    if (key == QLatin1String("privacy/adblock"))
        m_adBlocker->enabled = value.toBool();
    if (key == QLatin1String("appearance/theme"))
        applyColorScheme();
    if (key == QLatin1String("passwords/autoLockMinutes"))
        m_vault->setProperty("autoLockMinutes", value.toInt());
    ++m_settingsRevision;
    emit settingChanged();
}

void Browser::resetSetting(const QString &key)
{
    m_settings.remove(key);
    if (key == QLatin1String("appearance/theme"))
        applyColorScheme();
    ++m_settingsRevision;
    emit settingChanged();
}

void Browser::applyColorScheme()
{
    const QString theme = setting(QStringLiteral("appearance/theme"), QStringLiteral("dark")).toString();
    qApp->styleHints()->setColorScheme(theme == QLatin1String("light") ? Qt::ColorScheme::Light
                                       : theme == QLatin1String("dark") ? Qt::ColorScheme::Dark
                                                                         : Qt::ColorScheme::Unknown);   // = follow the system
}

// ---------------- windows and sessions ----------------

void Browser::newWindow(bool incognito)
{
    auto *engine = qobject_cast<QQmlApplicationEngine *>(qmlEngine(this));
    if (!engine)
        return;
    engine->setInitialProperties({ { "incognito", incognito } });
    engine->loadFromModule("f1int", "Main");
    engine->setInitialProperties({});
}

bool Browser::registerWindow(TabModel *tabs, bool incognito)
{
    if (incognito)
        return false;   // never saved
    m_windows.append(tabs);
    for (auto sig : { &TabModel::countChanged, &TabModel::currentIdChanged, &TabModel::groupsChanged })
        connect(tabs, sig, this, &Browser::scheduleSave);
    connect(tabs, &QAbstractItemModel::dataChanged, this, &Browser::scheduleSave);
    connect(tabs, &QAbstractItemModel::rowsMoved, this, &Browser::scheduleSave);

    if (m_pendingRestore.isEmpty())
        return false;
    tabs->fromJson(m_pendingRestore.takeFirst());
    // The other saved windows open as their own windows (each takes the next saved one).
    if (m_windows.size() == 1)
        for (int i = 0; i < m_pendingRestore.size(); ++i)
            QTimer::singleShot(0, this, [this] { newWindow(false); });
    return true;
}

void Browser::unregisterWindow(TabModel *tabs)
{
    // Closing the last window must not wipe the saved session: save it as it is first.
    if (m_windows.size() == 1 && m_windows.first() == tabs) {
        m_saveTimer.stop();
        writeSession();
    }
    m_windows.removeAll(tabs);
    if (!m_windows.isEmpty())
        scheduleSave();
}

QVariantMap Browser::takeStartUrls()
{
    if (m_startUrlsTaken)
        return { { "first", false }, { "urls", QVariantList() } };
    m_startUrlsTaken = true;
    // "f1int.exe example.com news.test" opens two tabs. Arguments starting with "-" are
    // options (Qt and Chromium accept some), so skip those.
    QVariantList urls;
    for (const QString &arg : QCoreApplication::arguments().mid(1))
        if (!arg.startsWith(QLatin1Char('-')))
            urls.append(urlFromInput(arg));
    return { { "first", true }, { "urls", urls } };
}

QQuickWebEngineProfile *Browser::createIncognitoProfile(QObject *window)
{
    auto *p = new QQuickWebEngineProfile(window);   // no storage name = nothing saved
    p->setOffTheRecord(true);
    setUpProfile(p);
    return p;
}

void Browser::scheduleSave()
{
    if (!setting(QStringLiteral("privacy/clearOnExit"), false).toBool())
        m_saveTimer.start();
}

void Browser::writeSession()
{
    QJsonArray windows;
    for (const QPointer<TabModel> &w : m_windows)
        if (w)
            windows.append(w->toJson());
    QSaveFile f(m_dataDir + QStringLiteral("/session.json"));   // writes to a temp file, then swaps: never half-written
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(QJsonObject{ { "windows", windows } }).toJson(QJsonDocument::Compact));
        f.commit();
    }
}

// ---------------- privacy and memory ----------------

void Browser::clearBrowsingData()
{
    m_library->clearHistory();
    m_profile->clearHttpCache();
    m_profile->cookieStore()->deleteAllCookies();
    QFile::remove(m_dataDir + QStringLiteral("/session.json"));
}

void Browser::loadFilterLists()
{
    QFile builtin(QStringLiteral(":/filters/builtin.txt"));
    if (builtin.open(QIODevice::ReadOnly))
        m_adBlocker->addList(builtin.readAll());

    // Full lists are downloaded from easylist.to, cached, and refreshed once a week.
    const QString dir = m_dataDir + QStringLiteral("/filters");
    QDir().mkpath(dir);
    auto *net = new QNetworkAccessManager(this);
    for (const char *name : { "easylist", "easyprivacy" }) {
        const QString path = dir + QLatin1Char('/') + QLatin1String(name) + QStringLiteral(".txt");
        QFile cached(path);
        if (cached.open(QIODevice::ReadOnly))
            m_adBlocker->addList(cached.readAll());
        const QFileInfo info(path);
        if (info.exists() && info.lastModified().daysTo(QDateTime::currentDateTime()) < 7)
            continue;
        QNetworkReply *reply = net->get(QNetworkRequest(QUrl(QStringLiteral("https://easylist.to/easylist/%1.txt").arg(QLatin1String(name)))));
        connect(reply, &QNetworkReply::finished, this, [this, reply, path] {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError)
                return;   // offline: keep using what we have
            const QByteArray list = reply->readAll();
            if (m_adBlocker->addList(list) > 1000) {   // looks like a real list: keep it
                QSaveFile out(path);
                if (out.open(QIODevice::WriteOnly)) { out.write(list); out.commit(); }
            }
        });
    }
}

QString Browser::passwordScript() const
{
    QFile f(QStringLiteral(":/scripts/passwords.js"));
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return QString::fromUtf8(f.readAll()).replace(QLatin1String("%NONCE%"), m_nonce);
}

void Browser::askDevice(QQuickWindow *window, const QString &purpose)
{
    const QString reason = purpose == QLatin1String("unlock") ? tr("Unlock your f1int passwords")
                                                              : tr("Confirm it's you to see this password");
    DeviceAuth::request(window, reason, [this, purpose](bool ok, const QString &error) {
        if (ok && purpose == QLatin1String("unlock"))
            ok = m_vault->unlockWithKeychain();
        else if (ok)
            m_vault->markVerified();
        emit deviceAuthFinished(purpose, ok, ok ? QString() : error);
    });
}

bool Browser::applyBackdrop(QQuickWindow *window, bool dark)
{
#ifdef Q_OS_WIN
    if (!window)
        return false;
    const HWND hwnd = HWND(window->winId());
    const BOOL useDark = dark;
    DwmSetWindowAttribute(hwnd, 20 /* DWMWA_USE_IMMERSIVE_DARK_MODE */, &useDark, sizeof useDark);
    // Let the backdrop show through the whole window (Qt draws on top of it with transparency).
    const MARGINS everywhere{ -1, -1, -1, -1 };
    DwmExtendFrameIntoClientArea(hwnd, &everywhere);
    const int acrylic = 3;   // DWMSBT_TRANSIENTWINDOW: blurred, tinted desktop behind the window
    return SUCCEEDED(DwmSetWindowAttribute(hwnd, 38 /* DWMWA_SYSTEMBACKDROP_TYPE, Windows 11 */, &acrylic, sizeof acrylic));
#else
    Q_UNUSED(window) Q_UNUSED(dark)
    return false;   // shortcut: no macOS vibrancy yet (needs NSVisualEffectView); solid colour instead
#endif
}

QVariantMap Browser::battery() const
{
#ifdef Q_OS_WIN
    SYSTEM_POWER_STATUS s;
    if (GetSystemPowerStatus(&s) && s.BatteryLifePercent <= 100 && !(s.BatteryFlag & 128))   // 128 = no battery
        return { { "percent", int(s.BatteryLifePercent) }, { "charging", s.ACLineStatus == 1 } };
#endif
    // shortcut: no battery reading on macOS yet (needs IOKit); the widget hides itself.
    return { { "percent", -1 }, { "charging", false } };
}

QVariantMap Browser::memoryInfo() const
{
    const QHash<qint64, qint64> mem = processTreeMemory();
    QVariantMap processes;
    qint64 total = 0;
    for (auto it = mem.cbegin(); it != mem.cend(); ++it) {
        processes.insert(QString::number(it.key()), it.value());
        total += it.value();
    }
    return { { "total", total }, { "browser", mem.value(QCoreApplication::applicationPid()) },
             { "processes", processes } };
}
