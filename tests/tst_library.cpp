// Checks bookmarks, history and address bar suggestions (in an in-memory database).
#include <QtTest>
#include "Library.h"

class TestLibrary : public QObject
{
    Q_OBJECT

private slots:
    void bookmarks()
    {
        Library lib(QStringLiteral(":memory:"));
        const QUrl url("https://example.com/");
        QVERIFY(!lib.isBookmarked(url));
        lib.addBookmark(url, "Example");
        QVERIFY(lib.isBookmarked(url));
        lib.addBookmark(url, "Example again");   // starring twice doesn't duplicate
        QCOMPARE(lib.bookmarks().size(), 1);
        QCOMPARE(lib.bookmarks("again").size(), 1);
        lib.removeBookmark(url);
        QVERIFY(!lib.isBookmarked(url));
    }

    void history()
    {
        Library lib(QStringLiteral(":memory:"));
        lib.addVisit(QUrl("https://news.test/a"), "News A");
        lib.addVisit(QUrl("https://news.test/a"), "News A");   // second visit counts up
        lib.addVisit(QUrl("about:blank"), "");                 // not a web page: ignored
        lib.addVisit(QUrl("https://mail.test/"), "Mail");
        const QVariantList h = lib.history();
        QCOMPARE(h.size(), 2);
        QCOMPARE(h[0].toMap()["url"].toString(), QString("https://mail.test/"));   // newest first
        QCOMPARE(h[1].toMap()["visits"].toInt(), 2);
        lib.removeHistory(QUrl("https://mail.test/"));
        QCOMPARE(lib.history().size(), 1);
        lib.clearHistory();
        QVERIFY(lib.history().isEmpty());
    }

    void suggestions()
    {
        Library lib(QStringLiteral(":memory:"));
        lib.addVisit(QUrl("https://www.wikipedia.org/"), "Wikipedia");
        lib.addVisit(QUrl("https://github.com/"), "GitHub");
        lib.addBookmark(QUrl("https://github.com/"), "GitHub");
        const QVariantList s = lib.suggest("git");
        QCOMPARE(s.size(), 1);                                    // bookmark and history entry merge
        QCOMPARE(s[0].toMap()["bookmark"].toInt(), 1);
        QCOMPARE(lib.suggest("wiki").size(), 1);                 // "www." is skipped when matching
        QCOMPARE(lib.suggest("encyclo").size(), 0);
        QVERIFY(lib.suggest("  ").isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestLibrary)
#include "tst_library.moc"
