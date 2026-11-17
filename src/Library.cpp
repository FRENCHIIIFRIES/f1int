#include "Library.h"

#include <QDateTime>
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
