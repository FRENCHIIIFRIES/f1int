// Tests for the updater's version and host checks (src/Updater.cpp).
#include <QtTest>
#include "Updater.h"

class TestUpdater : public QObject
{
    Q_OBJECT
private slots:
    void versions()
    {
        QVERIFY(Updater::isNewer("v0.2.0", "0.1.0"));
        QVERIFY(Updater::isNewer("0.1.10", "0.1.9"));   // numbers, not text
        QVERIFY(!Updater::isNewer("v0.1.0", "0.1.0"));
        QVERIFY(!Updater::isNewer("v0.0.9", "0.1.0"));
        QVERIFY(!Updater::isNewer("nightly", "0.1.0"));
    }
    void onlyGitHub()
    {
        QVERIFY(Updater::trustedHost(QUrl("https://github.com/FRENCHIIIFRIES/f1int/releases/download/v1/x.zip")));
        QVERIFY(Updater::trustedHost(QUrl("https://objects.githubusercontent.com/x")));
        QVERIFY(!Updater::trustedHost(QUrl("http://github.com/x")));          // not https
        QVERIFY(!Updater::trustedHost(QUrl("https://github.com.evil.test/x")));
        QVERIFY(!Updater::trustedHost(QUrl("https://evil.test/github.com")));
    }
};

QTEST_GUILESS_MAIN(TestUpdater)
#include "tst_updater.moc"
