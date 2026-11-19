#include "Library.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <functional>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QRegularExpression>
#include <QUuid>

Library::Library(const QString &dbPath, QObject *parent)
    : QObject(parent), m_connection(QUuid::createUuid().toString())   // each Library gets its own connection
{
    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connection);
    db.setDatabaseName(dbPath);
    if (!db.open())
        qWarning("f1int: cannot open %s: %s", qPrintable(dbPath), qPrintable(db.lastError().text()));
    exec(QStringLiteral("PRAGMA journal_mode=WAL"));   // safe if the browser crashes mid-write
    exec(QStringLiteral("CREATE TABLE IF NOT EXISTS bookmarks (url TEXT PRIMARY KEY, title TEXT, added INTEGER)"));
    exec(QStringLiteral("CREATE TABLE IF NOT EXISTS history (url TEXT PRIMARY KEY, title TEXT, last_visit INTEGER, visits INTEGER)"));

    // Where Chrome, Edge and Brave keep their data on this computer (for importing).
#if defined(Q_OS_WIN)
    const QString local = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);   // ...\AppData\Local
    const QString roaming = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation).replace("/Local", "/Roaming");
    browserRoots = { { "Chrome", local + "/Google/Chrome/User Data" }, { "Edge", local + "/Microsoft/Edge/User Data" },
                     { "Brave", local + "/BraveSoftware/Brave-Browser/User Data" },
                     { "Opera", roaming + "/Opera Software/Opera Stable" }, { "Opera GX", roaming + "/Opera Software/Opera GX Stable" },
                     { "Arc", local + "/Packages/TheBrowserCompany.Arc_ttt1ap7aakyb4/LocalCache/Local/Arc/User Data" } };
    firefoxRoot = roaming + "/Mozilla/Firefox";
#elif defined(Q_OS_MACOS)
    const QString support = QDir::homePath() + "/Library/Application Support";
    browserRoots = { { "Chrome", support + "/Google/Chrome" }, { "Edge", support + "/Microsoft Edge" },
                     { "Brave", support + "/BraveSoftware/Brave-Browser" }, { "Opera", support + "/com.operasoftware.Opera" },
                     { "Arc", support + "/Arc/User Data" } };
    firefoxRoot = support + "/Firefox";
#endif
}

Library::~Library()
{
    QSqlDatabase::database(m_connection).close();
    QSqlDatabase::removeDatabase(m_connection);
}

bool Library::isBookmarked(const QUrl &url) const
{
    return !query(QStringLiteral("SELECT 1 FROM bookmarks WHERE url = ?"), { url.toString() }).isEmpty();
}

void Library::addBookmark(const QUrl &url, const QString &title)
{
    if (url.isEmpty())
        return;
    exec(QStringLiteral("INSERT OR REPLACE INTO bookmarks (url, title, added) VALUES (?, ?, ?)"),
         { url.toString(), title, QDateTime::currentMSecsSinceEpoch() });
    bump();
}

void Library::removeBookmark(const QUrl &url)
{
    exec(QStringLiteral("DELETE FROM bookmarks WHERE url = ?"), { url.toString() });
    bump();
}

void Library::renameBookmark(const QUrl &url, const QString &title)
{
    exec(QStringLiteral("UPDATE bookmarks SET title = ? WHERE url = ?"), { title, url.toString() });
    bump();
}

QVariantList Library::bookmarks(const QString &filter) const
{
    return query(QStringLiteral("SELECT url, title, added AS time FROM bookmarks "
                                "WHERE url LIKE ? OR title LIKE ? ORDER BY added DESC"),
                 { QLatin1Char('%') + filter + QLatin1Char('%'), QLatin1Char('%') + filter + QLatin1Char('%') });
}

void Library::addVisit(const QUrl &url, const QString &title)
{
    // Only real web pages; not blank tabs, data: URLs or internal pages.
    if (url.scheme() != QLatin1String("http") && url.scheme() != QLatin1String("https"))
        return;
    exec(QStringLiteral("INSERT INTO history (url, title, last_visit, visits) VALUES (?, ?, ?, 1) ON CONFLICT(url) "
                        "DO UPDATE SET title = excluded.title, last_visit = excluded.last_visit, visits = visits + 1"),
         { url.toString(), title, QDateTime::currentMSecsSinceEpoch() });
    bump();
}

QVariantList Library::history(const QString &filter, int limit) const
{
    return query(QStringLiteral("SELECT url, title, last_visit AS time, visits FROM history "
                                "WHERE url LIKE ? OR title LIKE ? ORDER BY last_visit DESC, rowid DESC LIMIT ?"),
                 { QLatin1Char('%') + filter + QLatin1Char('%'), QLatin1Char('%') + filter + QLatin1Char('%'), limit });
}

void Library::removeHistory(const QUrl &url)
{
    exec(QStringLiteral("DELETE FROM history WHERE url = ?"), { url.toString() });
    bump();
}

void Library::clearHistory()
{
    exec(QStringLiteral("DELETE FROM history"));
    bump();
}

QVariantList Library::suggest(const QString &text, int limit) const
{
    const QString t = text.trimmed();
    if (t.isEmpty())
        return {};
    // Match the start of the address (without "https://www.") or any word of the title.
    const QVariantList args = { QStringLiteral("%://") + t + QLatin1Char('%'), QStringLiteral("%://www.") + t + QLatin1Char('%'),
                                QLatin1Char('%') + t + QLatin1Char('%'), limit };
    QVariantList out = query(QStringLiteral("SELECT url, title, 1 AS bookmark FROM bookmarks "
                                            "WHERE url LIKE ? OR url LIKE ? OR title LIKE ? LIMIT ?"), args);
    const QVariantList seen = out;
    for (const QVariant &h : query(QStringLiteral("SELECT url, title, 0 AS bookmark FROM history "
                                                  "WHERE url LIKE ? OR url LIKE ? OR title LIKE ? "
                                                  "ORDER BY visits DESC, last_visit DESC LIMIT ?"), args)) {
        if (out.size() >= limit)
            break;
        bool duplicate = false;
        for (const QVariant &s : seen)
            duplicate |= s.toMap()["url"] == h.toMap()["url"];
        if (!duplicate)
            out.append(h);
    }
    return out;
}

QString Library::predict(const QString &typed) const
{
    const QString t = typed.trimmed().toLower();
    static const QRegularExpression hostLike(QStringLiteral("^[a-z0-9][a-z0-9.-]*$"));
    if (t.isEmpty() || !hostLike.match(t).hasMatch())
        return {};
    // Your sites first: most visited, then bookmarks.
    const QVariantList args = { QStringLiteral("%://") + t + QLatin1Char('%'), QStringLiteral("%://www.") + t + QLatin1Char('%') };
    QVariantList rows = query(QStringLiteral("SELECT url FROM history WHERE url LIKE ? OR url LIKE ? ORDER BY visits DESC, last_visit DESC LIMIT 30"), args);
    rows += query(QStringLiteral("SELECT url FROM bookmarks WHERE url LIKE ? OR url LIKE ? LIMIT 30"), args);
    for (const QVariant &r : rows) {
        QString host = QUrl(r.toMap()["url"].toString()).host().toLower();
        if (host.startsWith(QLatin1String("www.")))
            host.remove(0, 4);
        if (host.startsWith(t) && host != t)
            return host;
    }
    // Before you've been anywhere: well-known sites, most used first.
    static const QStringList known = {
        "google.com", "youtube.com", "instagram.com", "facebook.com", "x.com", "whatsapp.com", "wikipedia.org", "reddit.com",
        "amazon.com", "netflix.com", "tiktok.com", "linkedin.com", "spotify.com", "open.spotify.com", "github.com", "chatgpt.com",
        "gmail.com", "mail.google.com", "outlook.com", "twitch.tv", "discord.com", "pinterest.com", "bing.com", "yahoo.com",
        "duckduckgo.com", "apple.com", "microsoft.com", "ebay.com", "paypal.com", "zoom.us", "canva.com", "quora.com",
        "stackoverflow.com", "imdb.com", "flipkart.com", "hotstar.com", "primevideo.com", "music.youtube.com", "maps.google.com",
        "drive.google.com", "docs.google.com", "claude.ai" };
    for (const QString &site : known)
        if (site.startsWith(t) && site != t)
            return site;
    return {};
}

// ---------------- import from Chrome / Edge / Brave ----------------

// Chrome stores times as microseconds since 1 January 1601; we use milliseconds since 1970.
static qint64 fromChromeTime(qint64 micros)
{
    return micros > 0 ? micros / 1000 - 11644473600000LL : QDateTime::currentMSecsSinceEpoch();
}

QVariantList Library::otherBrowserProfiles() const
{
    QVariantList out;
    for (const auto &[browser, root] : browserRoots) {
        const QDir dir(root);
        if (!dir.exists())
            continue;
        // "Local State" holds the names people gave their profiles ("Work", "Personal"...).
        QFile state(dir.filePath(QStringLiteral("Local State")));
        QJsonObject names;
        if (state.open(QIODevice::ReadOnly))
            names = QJsonDocument::fromJson(state.readAll())["profile"]["info_cache"].toObject();
        QStringList subs = dir.entryList({ QStringLiteral("Default"), QStringLiteral("Profile *") }, QDir::Dirs);
        if (QFile::exists(dir.filePath(QStringLiteral("History"))) || QFile::exists(dir.filePath(QStringLiteral("Bookmarks"))))
            subs.prepend(QStringLiteral("."));   // Opera: the folder itself is the profile
        for (const QString &sub : subs) {
            if (!QFile::exists(dir.filePath(sub + QStringLiteral("/History"))) && !QFile::exists(dir.filePath(sub + QStringLiteral("/Bookmarks"))))
                continue;
            QString name = names[sub].toObject()["name"].toString();
            out.append(QVariantMap{ { "browser", browser }, { "name", name.isEmpty() ? (sub == "." ? tr("Default") : sub) : name },
                                    { "path", QDir::cleanPath(dir.filePath(sub)) }, { "kind", "chromium" } });
        }
    }
    // Firefox: every folder under Profiles that has a places.sqlite (bookmarks + history).
    const QDir firefox(firefoxRoot + QStringLiteral("/Profiles"));
    for (const QString &sub : firefox.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (!QFile::exists(firefox.filePath(sub + QStringLiteral("/places.sqlite"))))
            continue;
        const QString name = sub.contains('.') ? sub.section('.', 1) : sub;   // "abc123.default-release" -> "default-release"
        out.append(QVariantMap{ { "browser", "Firefox" }, { "name", name }, { "path", firefox.filePath(sub) }, { "kind", "firefox" } });
    }
    return out;
}

// Reads another browser's SQLite file from a copy (plus its write-ahead log, which holds the
// newest entries), so the original is never touched, even while that browser is open.
static bool readCopy(const QString &source, const QString &sql, const std::function<void(QSqlQuery &)> &row)
{
    const QString dir = QDir::temp().filePath(QStringLiteral("f1int-import-%1").arg(QUuid::createUuid().toString(QUuid::Id128)));
    QDir().mkpath(dir);
    const QString copy = dir + QStringLiteral("/data.db");
    bool ok = QFile::copy(source, copy);
    if (ok && QFile::exists(source + QStringLiteral("-wal")))
        QFile::copy(source + QStringLiteral("-wal"), copy + QStringLiteral("-wal"));
    if (ok) {
        const QString name = QUuid::createUuid().toString();
        {
            QSqlDatabase other = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), name);
            other.setDatabaseName(copy);
            ok = other.open();
            if (ok) {
                QSqlQuery read(other);
                ok = read.exec(sql);
                while (ok && read.next())
                    row(read);
            }
        }
        QSqlDatabase::removeDatabase(name);
    }
    QDir(dir).removeRecursively();
    return ok;
}

QVariantMap Library::importProfile(const QString &profilePath, const QVariantMap &options)
{
    const bool wantBookmarks = options.value("bookmarks", true).toBool();
    const bool wantHistory = options.value("history", true).toBool();
    const bool dryRun = options.value("dryRun", false).toBool();
    int bookmarks = 0, history = 0;
    QString error, search;
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    db.transaction();   // one write instead of thousands; a dry run rolls it all back at the end
    QSqlQuery write(db);
    write.prepare(QStringLiteral("INSERT INTO history (url, title, last_visit, visits) VALUES (?, ?, ?, ?) "
                                 "ON CONFLICT(url) DO UPDATE SET visits = max(visits, excluded.visits), "
                                 "last_visit = max(last_visit, excluded.last_visit)"));
    const auto addVisit = [&](const QUrl &url, const QString &title, qint64 when, int visits) {
        if (url.scheme() != QLatin1String("http") && url.scheme() != QLatin1String("https"))
            return;
        write.addBindValue(url.toString());
        write.addBindValue(title);
        write.addBindValue(when);
        write.addBindValue(qMax(1, visits));
        if (write.exec())
            ++history;
    };
    const auto addBookmark = [&](const QUrl &url, const QString &title, qint64 when) {
        if (!url.isValid() || url.scheme().isEmpty() || url.scheme() == QLatin1String("place") || isBookmarked(url))
            return;
        exec(QStringLiteral("INSERT INTO bookmarks (url, title, added) VALUES (?, ?, ?)"), { url.toString(), title, when });
        ++bookmarks;
    };

    if (QFile::exists(profilePath + QStringLiteral("/places.sqlite"))) {
        // Firefox: bookmarks and history share one database. Times are microseconds since 1970.
        const QString places = profilePath + QStringLiteral("/places.sqlite");
        bool ok = true;
        if (wantBookmarks)
            ok = readCopy(places, QStringLiteral("SELECT p.url, b.title, b.dateAdded FROM moz_bookmarks b JOIN moz_places p ON p.id = b.fk WHERE b.type = 1"),
                          [&](QSqlQuery &q) { addBookmark(QUrl(q.value(0).toString()), q.value(1).toString(), q.value(2).toLongLong() / 1000); });
        if (ok && wantHistory)
            ok = readCopy(places, QStringLiteral("SELECT url, title, last_visit_date, visit_count FROM moz_places WHERE last_visit_date IS NOT NULL "
                                                 "AND hidden = 0 ORDER BY last_visit_date DESC LIMIT 50000"),
                          [&](QSqlQuery &q) { addVisit(QUrl(q.value(0).toString()), q.value(1).toString(), q.value(2).toLongLong() / 1000, q.value(3).toInt()); });
        if (!ok)
            error = tr("Couldn't read Firefox's data: close Firefox, then try again.");
        dryRun ? db.rollback() : db.commit();   // (Firefox's search setting is in a compressed format of its own: not read)
        goto done;
    }

    {
    // Search engine: Chromium browsers keep the default one in "Preferences".
    QFile prefs(profilePath + QStringLiteral("/Preferences"));
    if (options.value("search", true).toBool() && prefs.open(QIODevice::ReadOnly)) {
        const QString url = QJsonDocument::fromJson(prefs.readAll())["default_search_provider_data"]["template_url_data"]["url"].toString();
        if (url.contains(QLatin1String("{searchTerms}")))
            search = url.contains(QLatin1String("{google:baseURL}")) ? QStringLiteral("https://www.google.com/search?q=%s")
                                                                   : QString(url).replace(QLatin1String("{searchTerms}"), QLatin1String("%s"))
                                                                         .remove(QRegularExpression(QStringLiteral("[&?][^&?]*\\{[^}]*\\}[^&]*")));
    }

    // Bookmarks: a JSON file with folders inside folders. f1int keeps a flat list, so
    // every bookmark comes over; the folder names don't (yet).
    QFile file(profilePath + QStringLiteral("/Bookmarks"));
    if (wantBookmarks && file.open(QIODevice::ReadOnly)) {
        std::function<void(const QJsonObject &)> walk = [&](const QJsonObject &node) {
            if (node["type"].toString() == QLatin1String("url")) {
                const QUrl url(node["url"].toString());
                addBookmark(url, node["name"].toString(), fromChromeTime(node["date_added"].toString().toLongLong()));
            }
            for (const QJsonValue &child : node["children"].toArray())
                walk(child.toObject());
        };
        const QJsonObject roots = QJsonDocument::fromJson(file.readAll())["roots"].toObject();
        for (const QJsonValue &root : roots)
            walk(root.toObject());
    }

    // Arc keeps no Bookmarks file: its saved tabs (all spaces) are in StorableSidebar.json, two folders up.
    QFile sidebar(profilePath + QStringLiteral("/../../StorableSidebar.json"));
    if (wantBookmarks && sidebar.open(QIODevice::ReadOnly)) {
        std::function<void(const QJsonValue &)> walk = [&](const QJsonValue &v) {
            const QJsonObject tab = v["data"]["tab"].toObject();
            const QUrl url(tab["savedURL"].toString());
            if (url.isValid() && !url.host().endsWith(QLatin1String("arc.net")))   // skip Arc's own help pages
                addBookmark(url, v["title"].toString().isEmpty() ? tab["savedTitle"].toString() : v["title"].toString(),
                            QDateTime::currentMSecsSinceEpoch());
            const auto each = [&](const QJsonValue &c) { if (c.isObject() || c.isArray()) walk(c); };
            if (v.isArray()) for (const QJsonValue &c : v.toArray()) each(c);
            else for (const QJsonValue &c : v.toObject()) each(c);
        };
        walk(QJsonDocument::fromJson(sidebar.readAll())["sidebar"]);
    }

    // History: an SQLite database (read from a copy).
    const QString source = profilePath + QStringLiteral("/History");
    if (wantHistory && QFile::exists(source)
        && !readCopy(source, QStringLiteral("SELECT url, title, last_visit_time, visit_count FROM urls WHERE hidden = 0 "
                                            "ORDER BY last_visit_time DESC LIMIT 50000"),
                     [&](QSqlQuery &q) { addVisit(QUrl(q.value(0).toString()), q.value(1).toString(), fromChromeTime(q.value(2).toLongLong()), q.value(3).toInt()); }))
        error = tr("Couldn't read the history: close that browser, then try again.");
    }
    dryRun ? db.rollback() : db.commit();
done:
    if (!dryRun)
        bump();
    QVariantMap result{ { "bookmarks", bookmarks }, { "history", history }, { "search", search } };
    if (!error.isEmpty())
        result.insert(QStringLiteral("error"), error);
    return result;
}
QVariantList Library::query(const QString &sql, const QVariantList &args) const
{
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(sql);
    for (const QVariant &a : args)
        q.addBindValue(a);
    QVariantList rows;
    if (!q.exec()) {
        qWarning("f1int: query failed: %s", qPrintable(q.lastError().text()));
        return rows;
    }
    while (q.next()) {
        QVariantMap row;
        const QSqlRecord r = q.record();
        for (int i = 0; i < r.count(); ++i)
            row.insert(r.fieldName(i), q.value(i));
        rows.append(row);
    }
    return rows;
}

void Library::exec(const QString &sql, const QVariantList &args)
{
    query(sql, args);
}

int Library::importBookmarksHtml(const QUrl &file)
{
    // The "Netscape bookmark file" every browser exports: <A HREF="..." ADD_DATE="...">Title</A>
    QFile f(file.toLocalFile());
    if (!file.isLocalFile() || f.size() > 50 * 1024 * 1024 || !f.open(QIODevice::ReadOnly))
        return -1;
    const QString html = QString::fromUtf8(f.readAll());
    static const QRegularExpression link(QStringLiteral("<a\\s([^>]*)>(.*?)</a>"), QRegularExpression::CaseInsensitiveOption | QRegularExpression::DotMatchesEverythingOption);
    static const QRegularExpression href(QStringLiteral("href=\"([^\"]*)\""), QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression added(QStringLiteral("add_date=\"(\\d+)\""), QRegularExpression::CaseInsensitiveOption);
    const auto unescape = [](QString t) {
        return t.remove(QRegularExpression(QStringLiteral("<[^>]*>"))).replace("&lt;", "<").replace("&gt;", ">")
                .replace("&quot;", "\"").replace("&#39;", "'").replace("&amp;", "&").trimmed();
    };
    int count = 0;
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    db.transaction();
    for (auto it = link.globalMatch(html); it.hasNext();) {
        const auto m = it.next();
        const QUrl url(unescape(href.match(m.captured(1)).captured(1)));
        if (!url.isValid() || (url.scheme() != QLatin1String("http") && url.scheme() != QLatin1String("https")) || isBookmarked(url))
            continue;
        const qint64 secs = added.match(m.captured(1)).captured(1).toLongLong();
        exec(QStringLiteral("INSERT INTO bookmarks (url, title, added) VALUES (?, ?, ?)"),
             { url.toString(), unescape(m.captured(2)), secs > 0 ? secs * 1000 : QDateTime::currentMSecsSinceEpoch() });
        ++count;
    }
    db.commit();
    bump();
    return count;
}

bool Library::exportBookmarksHtml(const QUrl &file) const
{
    const auto esc = [](QString t) { return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;"); };
    QString out = QStringLiteral("<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">\n"
                                 "<TITLE>Bookmarks</TITLE>\n<H1>Bookmarks</H1>\n<DL><p>\n");
    for (const QVariant &v : bookmarks()) {
        const QVariantMap b = v.toMap();
        out += QStringLiteral("    <DT><A HREF=\"%1\" ADD_DATE=\"%2\">%3</A>\n")
                   .arg(esc(b["url"].toString())).arg(b["added"].toLongLong() / 1000).arg(esc(b["title"].toString()));
    }
    out += QStringLiteral("</DL><p>\n");
    QFile f(file.toLocalFile());
    return file.isLocalFile() && f.open(QIODevice::WriteOnly | QIODevice::Truncate) && f.write(out.toUtf8()) >= 0;
}

int Library::addHistory(const QVariantList &entries)
{
    int count = 0;
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    db.transaction();
    for (const QVariant &v : entries) {
        const QVariantMap e = v.toMap();
        const QUrl url(e["url"].toString());
        if (url.scheme() != QLatin1String("http") && url.scheme() != QLatin1String("https"))
            continue;
        exec(QStringLiteral("INSERT INTO history (url, title, last_visit, visits) VALUES (?, ?, ?, ?) ON CONFLICT(url) DO UPDATE SET "
                            "visits = max(visits, excluded.visits), last_visit = max(last_visit, excluded.last_visit)"),
             { url.toString(), e["title"].toString(), (e.contains("last_visit") ? e["last_visit"] : e["time"]).toLongLong(), qMax(1, e["visits"].toInt()) });
        ++count;
    }
    db.commit();
    bump();
    return count;
}
