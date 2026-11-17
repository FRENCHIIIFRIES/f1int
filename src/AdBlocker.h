#pragma once

#include <QElapsedTimer>
#include <QHash>
#include <QSet>
#include <QWebEngineUrlRequestInterceptor>

// Blocks requests to ad and tracker servers before they leave the browser (less data,
// less tracking, less RAM). Uses the domain rules of EasyList-style filter lists
// ("||ads.example.com^"); cosmetic rules (hiding page elements) are not supported.
// shortcut: domain rules only, no path/regex rules; covers most ads and trackers.
// Upgrade to a full filter engine (e.g. adblock-rust) if blocking is too weak.
class AdBlocker : public QWebEngineUrlRequestInterceptor
{
    Q_OBJECT

public:
    explicit AdBlocker(QObject *parent = nullptr);

    void interceptRequest(QWebEngineUrlRequestInfo &info) override;

    // Adds the domain rules from a filter list. Returns how many rules were read.
    int addList(const QByteArray &list);
    // Would a request to `host`, made by a page on `pageHost`, be blocked?
    bool blocks(const QString &host, const QString &pageHost) const;

    bool enabled = true;
    int blockedTotal() const { return m_blockedTotal; }

signals:
    // A page on `pageHost` made a request (sent at most ~4 times a second per site).
    void activity(const QString &pageHost);
    void blocked(const QString &pageHost);

private:
    static bool matches(const QSet<QString> &set, QString host);

    QSet<QString> m_block;            // "||host^"
    QSet<QString> m_blockThirdParty;  // "||host^$third-party": only when loaded by another site
    QSet<QString> m_allow;            // "@@||host^": exceptions
    QHash<QString, qint64> m_lastActivity;
    QElapsedTimer m_clock;
    int m_blockedTotal = 0;
};
