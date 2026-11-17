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
};

QTEST_GUILESS_MAIN(TestAdBlocker)
#include "tst_adblocker.moc"
