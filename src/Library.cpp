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
    browserRoots = { { "Chrome", local + "/Google/Chrome/User Data" }, { "Edge", local + "/Microsoft/Edge/User Data" },
                     { "Brave", local + "/BraveSoftware/Brave-Browser/User Data" } };
#elif defined(Q_OS_MACOS)
    const QString support = QDir::homePath() + "/Library/Application Support";
    browserRoots = { { "Chrome", support + "/Google/Chrome" }, { "Edge", support + "/Microsoft Edge" },
                     { "Brave", support + "/BraveSoftware/Brave-Browser" } };
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
        for (const QString &sub : dir.entryList({ QStringLiteral("Default"), QStringLiteral("Profile *") }, QDir::Dirs)) {
            if (!QFile::exists(dir.filePath(sub + QStringLiteral("/History"))) && !QFile::exists(dir.filePath(sub + QStringLiteral("/Bookmarks"))))
                continue;
            QString name = names[sub].toObject()["name"].toString();
            out.append(QVariantMap{ { "browser", browser }, { "name", name.isEmpty() ? sub : name }, { "path", dir.filePath(sub) } });
        }
    }
    return out;
}

QVariantMap Library::importProfile(const QString &profilePath)
{
    int bookmarks = 0, history = 0;
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    db.transaction();   // one write instead of thousands: much faster

    // Bookmarks: a JSON file with folders inside folders. f1int keeps a flat list, so
    // every bookmark comes over; the folder names don't (yet).
    QFile file(profilePath + QStringLiteral("/Bookmarks"));
    if (file.open(QIODevice::ReadOnly)) {
        std::function<void(const QJsonObject &)> walk = [&](const QJsonObject &node) {
            if (node["type"].toString() == QLatin1String("url")) {
                const QUrl url(node["url"].toString());
                if (url.isValid() && !isBookmarked(url)) {
                    exec(QStringLiteral("INSERT INTO bookmarks (url, title, added) VALUES (?, ?, ?)"),
                         { url.toString(), node["name"].toString(), fromChromeTime(node["date_added"].toString().toLongLong()) });
                    ++bookmarks;
                }
            }
            for (const QJsonValue &child : node["children"].toArray())
                walk(child.toObject());
        };
        const QJsonObject roots = QJsonDocument::fromJson(file.readAll())["roots"].toObject();
        for (const QJsonValue &root : roots)
            walk(root.toObject());
    }

    // History: an SQLite database. Read a copy, so the other browser's file is never touched.
    QString error;
    const QString source = profilePath + QStringLiteral("/History");
    if (QFile::exists(source)) {
        const QString copy = QDir::temp().filePath(QStringLiteral("f1int-import-%1.db").arg(QUuid::createUuid().toString(QUuid::Id128)));
        if (!QFile::copy(source, copy)) {
            error = tr("Couldn't read the history: close that browser first, then import again.");
        } else {
            const QString name = QUuid::createUuid().toString();
            {
                QSqlDatabase other = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), name);
                other.setDatabaseName(copy);
                other.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
                if (other.open()) {
                    QSqlQuery read(other);
                    read.exec(QStringLiteral("SELECT url, title, last_visit_time, visit_count FROM urls "
                                             "WHERE hidden = 0 ORDER BY last_visit_time DESC LIMIT 50000"));
                    QSqlQuery write(db);
                    write.prepare(QStringLiteral("INSERT INTO history (url, title, last_visit, visits) VALUES (?, ?, ?, ?) "
                                                 "ON CONFLICT(url) DO UPDATE SET visits = max(visits, excluded.visits), "
                                                 "last_visit = max(last_visit, excluded.last_visit)"));
                    while (read.next()) {
                        const QUrl url(read.value(0).toString());
                        if (url.scheme() != QLatin1String("http") && url.scheme() != QLatin1String("https"))
                            continue;
                        write.addBindValue(url.toString());
                        write.addBindValue(read.value(1).toString());
                        write.addBindValue(fromChromeTime(read.value(2).toLongLong()));
                        write.addBindValue(qMax(1, read.value(3).toInt()));
                        if (write.exec())
                            ++history;
                    }
                } else {
                    error = tr("That history file couldn't be opened.");
                }
            }
            QSqlDatabase::removeDatabase(name);
            QFile::remove(copy);
        }
    }
    db.commit();
    bump();
    QVariantMap result{ { "bookmarks", bookmarks }, { "history", history } };
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
