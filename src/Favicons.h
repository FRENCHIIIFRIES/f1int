#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QSet>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

// Site icons that last: Qt WebEngine only keeps icons of pages open right now, so bookmarks
// and history would show a globe. f1int keeps a small copy per site: saved when you visit a
// page, or fetched from the site itself (its own /favicon.ico, never a third-party service)
// the first time a bookmark needs one. Stored as 32 px PNGs in the profile's "favicons" folder.
class Favicons : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Use Browser.favicons")
    Q_PROPERTY(int revision READ revision NOTIFY changed)   // goes up when an icon arrives

public:
    explicit Favicons(const QString &dir, QObject *parent = nullptr);

    int revision() const { return m_revision; }
    // The stored icon for a page's site, or an empty URL (then one is fetched in the background).
    Q_INVOKABLE QUrl icon(const QUrl &page);
    // A page loaded and showed this icon (the engine's "image://favicon/<icon address>").
    Q_INVOKABLE void pageIcon(const QUrl &page, const QUrl &engineIcon);
    static QString keyFor(const QUrl &page);   // "github.com" (no www), or "" if not a web page

signals:
    void changed();

private:
    void fetch(const QString &key, const QUrl &from, bool fallback);
    QString file(const QString &key) const { return m_dir + QLatin1Char('/') + key + QStringLiteral(".png"); }
    QNetworkAccessManager m_net;
    QString m_dir;
    QSet<QString> m_tried;   // asked once per run, so a site without an icon isn't asked again and again
    int m_revision = 0;
};
