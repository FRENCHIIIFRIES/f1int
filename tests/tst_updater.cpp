// Tests for the updater's version and host checks (src/Updater.cpp).
#include <QtTest>
#include "Updater.h"
#include "WebStore.h"

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
    void chromePackages()
    {
        QByteArray zip("PK\x03\x04rest-of-zip", 16);
        QByteArray crx3("Cr24", 4);
        crx3 += QByteArray("\x03\0\0\0", 4) + QByteArray("\x05\0\0\0", 4) + "HEADR" + zip;
        QCOMPARE(WebStore::zipFromCrx(crx3), zip);
        QByteArray crx2("Cr24", 4);
        crx2 += QByteArray("\x02\0\0\0", 4) + QByteArray("\x02\0\0\0", 4) + QByteArray("\x01\0\0\0", 4) + "KYS" + zip;
        QCOMPARE(WebStore::zipFromCrx(crx2), zip);
        QVERIFY(WebStore::zipFromCrx("Cr24junk-not-a-package").isEmpty());
        QVERIFY(WebStore::zipFromCrx(crx3.left(20)).isEmpty());   // cut short
        QCOMPARE(WebStore::webStoreId(QUrl("https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh")),
                 QString("ddkjiahejlhfcafbddmgiahcphecmpfh"));
        QVERIFY(WebStore::webStoreId(QUrl("https://evil.test/detail/x/ddkjiahejlhfcafbddmgiahcphecmpfh")).isEmpty());
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
