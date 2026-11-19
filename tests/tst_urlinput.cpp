// Checks that the address bar turns typed text into the right URL or search.
#include <QtTest>
#include "UrlInput.h"

static const QString Search = QStringLiteral("https://search.test/?q=%s");

class TestUrlInput : public QObject
{
    Q_OBJECT

private slots:
    void cases_data()
    {
        QTest::addColumn<QString>("input");
        QTest::addColumn<QString>("expected");
        const QString s = QStringLiteral("https://search.test/?q=");

        QTest::newRow("domain") << "example.com" << "https://example.com";
        QTest::newRow("domain with path") << "example.com/a?b=1" << "https://example.com/a?b=1";
        QTest::newRow("spaces around") << "  example.com  " << "https://example.com";
        QTest::newRow("explicit http") << "http://example.com" << "http://example.com";
        QTest::newRow("about page") << "about:blank" << "about:blank";
        QTest::newRow("localhost port") << "localhost:3000" << "http://localhost:3000";
        QTest::newRow("ipv4") << "192.168.1.1/admin" << "http://192.168.1.1/admin";
        QTest::newRow("ipv6") << "[::1]:8080" << "http://[::1]:8080";
        QTest::newRow("several words") << "how to cook rice" << s + "how%20to%20cook%20rice";
        QTest::newRow("one word") << "weather" << s + "weather";
        QTest::newRow("trailing dot") << "hello." << s + "hello.";
        QTest::newRow("a number") << "3.14" << s + "3.14";
        QTest::newRow("symbols") << "c++ a&b" << s + "c%2B%2B%20a%26b";
    }

    void cases()
    {
        QFETCH(QString, input);
        QFETCH(QString, expected);
        QCOMPARE(urlFromInput(input, Search).toString(QUrl::FullyEncoded), expected);
    }

    void empty() { QVERIFY(urlFromInput(QStringLiteral("   "), Search).isEmpty()); }
};

// (a file on this computer becomes a file address; see urlFromInput)
QTEST_APPLESS_MAIN(TestUrlInput)
#include "tst_urlinput.moc"
