// Checks filter-list parsing and which requests get blocked.
#include <QtTest>
#include "AdBlocker.h"

class TestAdBlocker : public QObject
{
    Q_OBJECT

private slots:
    void rules()
    {
        AdBlocker b;
        const int n = b.addList("! comment\n"
                                "||ads.example^\n"
                                "||tracker.test^$third-party\n"
                                "@@||good.ads.example^\n"
                                "##.banner\n"                       // cosmetic: ignored
                                "||cdn.test/ads/*.js\n"             // path rule: ignored
                                "||ADS.UPPER^\r\n");                // case and Windows line ends
        QCOMPARE(n, 4);
        QVERIFY(b.blocks("ads.example", "news.test"));
        QVERIFY(b.blocks("img.ads.example", "news.test"));          // subdomains too
        QVERIFY(!b.blocks("badads.example", "news.test"));          // but not look-alikes
        QVERIFY(!b.blocks("good.ads.example", "news.test"));        // exception wins
        QVERIFY(b.blocks("ads.upper", "news.test"));
        QVERIFY(b.blocks("tracker.test", "news.test"));             // third-party: blocked
        QVERIFY(!b.blocks("tracker.test", "www.tracker.test"));     // on its own site: allowed
        QVERIFY(!b.blocks("example.org", "news.test"));
    }

    void googleSignInSeesTheEngine()
    {
        AdBlocker b;
        QVERIFY(b.userAgentFor(QUrl("https://accounts.google.com/"), QUrl("https://accounts.google.com/")).isEmpty());  // not set yet
        b.engineUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) "
                            "QtWebEngine/6.12.0 Chrome/140.0.0.0 Safari/537.36";
        const QUrl signIn("https://accounts.google.com/v3/signin/identifier");
        QCOMPARE(b.userAgentFor(signIn, signIn), b.engineUserAgent);
        QCOMPARE(b.userAgentFor(QUrl("https://www.gstatic.com/a.js"), signIn), b.engineUserAgent);        // what the page loads
        QCOMPARE(b.userAgentFor(QUrl("https://accounts.google.com/gsi/button"), QUrl("https://shop.test/")),
                 b.engineUserAgent);                                                                     // "Sign in with Google" frames
        QCOMPARE(b.userAgentFor(QUrl("https://ACCOUNTS.YOUTUBE.COM/"), QUrl()), b.engineUserAgent);
        QVERIFY(b.userAgentFor(QUrl("https://www.google.com/"), QUrl("https://www.google.com/")).isEmpty());  // everywhere else: unchanged
        QVERIFY(b.userAgentFor(QUrl("https://accounts.google.com.evil.test/"), QUrl()).isEmpty());
        QVERIFY(b.userAgentFor(QUrl("http://accounts.google.com/"), QUrl()).isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestAdBlocker)
#include "tst_adblocker.moc"
