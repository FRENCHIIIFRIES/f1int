// Checks bookmarks, history and address bar suggestions (in an in-memory database).
#include <QtTest>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QTemporaryDir>
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

    void importFromChrome()
    {
        // A fake Chrome "User Data" folder with one profile, in Chrome's own file formats.
        QTemporaryDir root;
        QDir(root.path()).mkpath("Default");
        const auto writeJson = [&](const QString &name, const QJsonObject &json) {
            QFile f(root.filePath(name));
            QVERIFY(f.open(QIODevice::WriteOnly));
            f.write(QJsonDocument(json).toJson());
        };
        writeJson("Local State", QJsonObject{ { "profile", QJsonObject{ { "info_cache",
                      QJsonObject{ { "Default", QJsonObject{ { "name", "Personal" } } } } } } } });
        const QJsonObject news{ { "type", "url" }, { "name", "News" }, { "url", "https://news.test/" }, { "date_added", "13350000000000000" } };
        const QJsonObject mail{ { "type", "url" }, { "name", "Mail" }, { "url", "https://mail.test/" } };
        const QJsonObject work{ { "type", "folder" }, { "name", "Work" }, { "children", QJsonArray{ mail } } };   // a folder inside
        writeJson("Default/Bookmarks", QJsonObject{ { "roots", QJsonObject{
                      { "bookmark_bar", QJsonObject{ { "type", "folder" }, { "children", QJsonArray{ news, work } } } },
                      { "other", QJsonObject{ { "type", "folder" }, { "children", QJsonArray{} } } } } } });
        {
            QSqlDatabase h = QSqlDatabase::addDatabase("QSQLITE", "fake-chrome");
            h.setDatabaseName(root.filePath("Default/History"));
            QVERIFY(h.open());
            QSqlQuery q(h);
            QVERIFY(q.exec("CREATE TABLE urls (id INTEGER PRIMARY KEY, url TEXT, title TEXT, visit_count INTEGER, "
                           "typed_count INTEGER, last_visit_time INTEGER, hidden INTEGER)"));
            QVERIFY(q.exec("INSERT INTO urls VALUES (1, 'https://news.test/a', 'A', 3, 0, 13350000000000000, 0)"));
            QVERIFY(q.exec("INSERT INTO urls VALUES (2, 'chrome://settings/', 'Settings', 1, 0, 13350000000000000, 0)"));
            QVERIFY(q.exec("INSERT INTO urls VALUES (3, 'https://hidden.test/', 'H', 1, 0, 13350000000000000, 1)"));
            h.close();
        }
        QSqlDatabase::removeDatabase("fake-chrome");

        Library lib(QStringLiteral(":memory:"));
        lib.browserRoots = { { "Chrome", root.path() } };
        const QVariantList profiles = lib.otherBrowserProfiles();
        QCOMPARE(profiles.size(), 1);
        QCOMPARE(profiles[0].toMap()["name"].toString(), QString("Personal"));

        lib.firefoxRoot = root.filePath("no-firefox-here");
        const QVariantMap preview = lib.importProfile(profiles[0].toMap()["path"].toString(), { { "dryRun", true } });
        QCOMPARE(preview["bookmarks"].toInt(), 2);         // a dry run counts...
        QCOMPARE(lib.bookmarks().size(), 0);              // ...but adds nothing
        const QVariantMap result = lib.importProfile(profiles[0].toMap()["path"].toString());
        QCOMPARE(result["bookmarks"].toInt(), 2);          // including the one inside a folder
        QCOMPARE(result["history"].toInt(), 1);            // chrome:// and hidden entries skipped
        QVERIFY(!result.contains("error"));
        QCOMPARE(lib.history().first().toMap()["visits"].toInt(), 3);
        QCOMPARE(lib.importProfile(profiles[0].toMap()["path"].toString())["bookmarks"].toInt(), 0);   // no duplicates
    }

    void importFromArc()
    {
        // Arc: "<root>/User Data/Default" for history, saved tabs in "<root>/StorableSidebar.json".
        QTemporaryDir root;
        QDir(root.path()).mkpath("User Data/Default");
        QFile(root.filePath("User Data/Default/History")).open(QIODevice::WriteOnly);   // (empty: just marks the profile)
        const QJsonObject tab{ { "title", "" }, { "data", QJsonObject{ { "tab", QJsonObject{ { "savedURL", "https://pinned.test/" }, { "savedTitle", "Pinned" } } } } } };
        const QJsonObject help{ { "data", QJsonObject{ { "tab", QJsonObject{ { "savedURL", "https://resources.arc.net/x" } } } } } };
        QFile f(root.filePath("StorableSidebar.json"));
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(QJsonDocument(QJsonObject{ { "sidebar", QJsonObject{ { "containers", QJsonArray{ QJsonObject{ { "items", QJsonArray{ "id", tab, help } } } } } } } }).toJson());
        f.close();
        Library lib(QStringLiteral(":memory:"));
        lib.browserRoots = { { "Arc", root.filePath("User Data") } };
        lib.firefoxRoot = root.filePath("no-firefox-here");
        const QVariantList profiles = lib.otherBrowserProfiles();
        QCOMPARE(profiles.size(), 1);
        const QVariantMap result = lib.importProfile(profiles[0].toMap()["path"].toString(), { { "history", false } });
        QCOMPARE(result["bookmarks"].toInt(), 1);   // the saved tab, not Arc's help page
        QCOMPARE(lib.bookmarks().first().toMap()["title"].toString(), QString("Pinned"));
    }
    void predictsTheSite()
    {
        Library lib(QStringLiteral(":memory:"));
        QCOMPARE(lib.predict("you"), QString("youtube.com"));       // well-known, before any history
        QCOMPARE(lib.predict("insta"), QString("instagram.com"));
        QCOMPARE(lib.predict("hello world"), QString());           // a search, not a site
        QCOMPARE(lib.predict("youtube.com"), QString());           // already complete
        lib.addVisit(QUrl("https://www.yourfavourite.test/page"), "Fav");
        lib.addVisit(QUrl("https://www.yourfavourite.test/other"), "Fav");
        QCOMPARE(lib.predict("you"), QString("yourfavourite.test"));   // your own sites win
    }
    void historyBackupKeepsTimes()
    {
        Library from(QStringLiteral(":memory:")), to(QStringLiteral(":memory:"));
        from.addVisit(QUrl("https://a.test/"), "A");
        const qint64 when = from.history().first().toMap()["time"].toLongLong();
        QVERIFY(when > 0);
        QCOMPARE(to.addHistory(from.history()), 1);   // what a backup carries
        QCOMPARE(to.history().first().toMap()["time"].toLongLong(), when);
    }
    void bookmarksHtmlRoundTrip()
    {
        QTemporaryDir dir;
        const QString in = dir.filePath("in.html");
        QFile f(in);
        QVERIFY(f.open(QIODevice::WriteOnly));
        // What browsers export: folders (<H3>), escaped titles, upper-case tags, a non-web link.
        f.write("<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<DL><p>\n<DT><H3>Work</H3>\n<DL><p>\n"
                "<DT><A HREF=\"https://a.test/?x=1&amp;y=2\" ADD_DATE=\"1700000000\">Tom &amp; Jerry &lt;3</A>\n</DL><p>\n"
                "<dt><a href=\"https://b.test/\">B</a>\n<DT><A HREF=\"javascript:alert(1)\">bad</A>\n</DL><p>\n");
        f.close();
        Library lib(QStringLiteral(":memory:"));
        QCOMPARE(lib.importBookmarksHtml(QUrl::fromLocalFile(in)), 2);   // the javascript: link is skipped
        QCOMPARE(lib.importBookmarksHtml(QUrl::fromLocalFile(in)), 0);   // nothing twice
        QVERIFY(lib.isBookmarked(QUrl("https://a.test/?x=1&y=2")));
        const QString out = dir.filePath("out.html");
        QVERIFY(lib.exportBookmarksHtml(QUrl::fromLocalFile(out)));
        Library other(QStringLiteral(":memory:"));
        QCOMPARE(other.importBookmarksHtml(QUrl::fromLocalFile(out)), 2);
        const QVariantList all = other.bookmarks();
        QVERIFY(std::any_of(all.begin(), all.end(), [](const QVariant &b) { return b.toMap()["title"].toString() == "Tom & Jerry <3"; }));
    }
};

QTEST_GUILESS_MAIN(TestLibrary)
#include "tst_library.moc"
