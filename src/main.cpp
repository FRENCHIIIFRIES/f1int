#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>

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
    QCoreApplication::setApplicationName(QStringLiteral("f1int"));

    applyChromiumFlags();
    QtWebEngineQuick::initialize();   // must come before the app object is created
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("f1int", "Main");   // loads qml/Main.qml
    return app.exec();
}
