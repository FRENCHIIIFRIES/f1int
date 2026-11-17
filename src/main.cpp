#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QSettings>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>
#include "Browser.h"
#include "Profiles.h"

// Chromium command-line switches. Qt WebEngine reads them once, when it starts,
// so they must be set before anything web-related is created.
// Start with F1INT_NO_FLAGS=1 to skip them; we use that to measure what they save.
// Note: we never pass --no-sandbox. Chromium's sandbox stays on.
static void applyChromiumFlags()
{
    if (qEnvironmentVariableIsSet("F1INT_NO_FLAGS"))
        return;
    const QByteArray ours =
        // Tabs on the same site (say, 5 YouTube tabs) share one renderer process
        // instead of one each. Different sites still never share (site isolation stays on).
        " --process-per-site"
        // Soft cap on renderer processes. Chromium may go over it to keep sites isolated.
        " --renderer-process-limit=6"
        // BackForwardCache: keeps the page you just left alive in RAM so Back is instant.
        // SpareRendererForSitePerProcess: Chromium starts an empty renderer "just in case".
        // We'd rather keep that RAM free.
        " --disable-features=BackForwardCache,SpareRendererForSitePerProcess";
    // Keep any flags the user set themselves, and add ours after them.
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", qgetenv("QTWEBENGINE_CHROMIUM_FLAGS") + ours);
}

int main(int argc, char *argv[])
{
    // These names decide where settings and the browser profile are stored on disk.
    QCoreApplication::setOrganizationName(QStringLiteral("f1int"));
    // UI test runs get their own data folder and settings, so they never touch the user's.
    // F1INT_TEST_NAME lets several test runs work side by side (each "f1int-test-…").
    const QString testName = qEnvironmentVariable("F1INT_TEST_NAME");
    Profiles::family = !qEnvironmentVariableIsSet("F1INT_UI_TEST") ? QStringLiteral("f1int")
                       : testName.startsWith(QLatin1String("f1int-test")) ? testName : QStringLiteral("f1int-test");
    // --profile=<id> opens another local profile (see Profiles.h); "first" is the first one.
    QString profile;
    for (int i = 1; i < argc; ++i) {
        const QString arg = QString::fromLocal8Bit(argv[i]);
        if (arg.startsWith(QLatin1String("--profile=")))
            profile = arg.mid(10) == QLatin1String("first") ? QString() : arg.mid(10);
    }
    if (!Profiles::validId(profile))
        profile.clear();
    QCoreApplication::setApplicationName(Profiles::appNameFor(profile));
    Browser::startProfile = profile;

    applyChromiumFlags();
    QtWebEngineQuick::initialize();   // must come before the app object is created
    QQuickWindow::setDefaultAlphaBuffer(true);   // windows can be see-through (frosted-glass backdrop)
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationVersion(QStringLiteral(F1INT_VERSION));
    app.setWindowIcon(QIcon(QStringLiteral(":/logo/f1int.svg")));
    QFontDatabase::addApplicationFont(QStringLiteral(":/fonts/Doto.ttf"));   // optional dot-matrix numbers

    // The UI font (Settings > Appearance > Font). "System" = the platform's own UI font;
    // on Windows 11 that's Segoe UI Variable, which reads nicely at small sizes.
    QString family = QSettings().value(QStringLiteral("appearance/font")).toString();
    if (family.isEmpty() && QFontDatabase::hasFamily(QStringLiteral("Segoe UI Variable Text")))
        family = QStringLiteral("Segoe UI Variable Text");
    if (!family.isEmpty()) {
        QFont font = QGuiApplication::font();
        font.setFamily(family);
        QGuiApplication::setFont(font);
    }

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("f1int", "Main");   // loads qml/Main.qml
    return app.exec();
}
