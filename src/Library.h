#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Bookmarks ("starred" sites) and history, kept in one small SQLite file in the
// browser's data folder. Incognito windows never write here.
class Library : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Use Browser.library")
    // Goes up by one on every change; QML bindings read it so they refresh (e.g. the star icon).
    Q_PROPERTY(int revision READ revision NOTIFY changed)

public:
    // dbPath ":memory:" keeps everything in RAM (used by the tests).
    explicit Library(const QString &dbPath, QObject *parent = nullptr);
    ~Library() override;

    int revision() const { return m_revision; }

    // ---- bookmarks ----
    Q_INVOKABLE bool isBookmarked(const QUrl &url) const;
    Q_INVOKABLE void addBookmark(const QUrl &url, const QString &title);
    Q_INVOKABLE void removeBookmark(const QUrl &url);
    Q_INVOKABLE void renameBookmark(const QUrl &url, const QString &title);
    Q_INVOKABLE QVariantList bookmarks(const QString &filter = {}) const;   // newest first

    // ---- history ----
    Q_INVOKABLE void addVisit(const QUrl &url, const QString &title);
    Q_INVOKABLE QVariantList history(const QString &filter = {}, int limit = 300) const;   // newest first
    Q_INVOKABLE void removeHistory(const QUrl &url);
    Q_INVOKABLE void clearHistory();

    // Address bar suggestions: bookmarks first, then the most visited history.
    Q_INVOKABLE QVariantList suggest(const QString &text, int limit = 6) const;

    // ---- import from Chrome, Edge or Brave on this computer ----
    // [{ browser, name, path }] for every profile found.
    Q_INVOKABLE QVariantList otherBrowserProfiles() const;
    // Copies bookmarks and history from a profile folder. Returns { bookmarks, history }
    // (how many were added) or { error } with a message for the user.
    Q_INVOKABLE QVariantMap importProfile(const QString &profilePath);
    // Where to look for other browsers' data (tests point this at a fake folder).
    QList<QPair<QString, QString>> browserRoots;   // (browser name, "User Data" folder)

signals:
    void changed();

private:
    QVariantList query(const QString &sql, const QVariantList &args) const;
    void exec(const QString &sql, const QVariantList &args = {});
    void bump() { ++m_revision; emit changed(); }

    QString m_connection;
    int m_revision = 0;
};
