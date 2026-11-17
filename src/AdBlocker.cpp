#include "AdBlocker.h"

#include <QRegularExpression>

AdBlocker::AdBlocker(QObject *parent) : QWebEngineUrlRequestInterceptor(parent)
{
    m_clock.start();
}

int AdBlocker::addList(const QByteArray &list)
{
    static const QRegularExpression hostRule(QStringLiteral("^(@@)?\\|\\|([a-z0-9.-]+)\\^(\\$third-party)?$"));
    int count = 0;
    for (const QByteArray &raw : list.split('\n')) {
        const QRegularExpressionMatch m = hostRule.match(QString::fromLatin1(raw.trimmed()).toLower());
        if (!m.hasMatch())
            continue;   // comments, cosmetic rules, path rules and rules with other options
        const QString host = m.captured(2);
        if (!m.captured(1).isEmpty())
            m_allow.insert(host);
        else if (!m.captured(3).isEmpty())
            m_blockThirdParty.insert(host);
        else
            m_block.insert(host);
        ++count;
    }
    return count;
}

// True if `host` or one of its parent domains is in the set ("a.ads.com" matches "ads.com").
bool AdBlocker::matches(const QSet<QString> &set, QString host)
{
    while (!host.isEmpty()) {
        if (set.contains(host))
            return true;
        const int dot = host.indexOf(QLatin1Char('.'));
        if (dot < 0)
            break;
        host = host.mid(dot + 1);
    }
    return false;
}

bool AdBlocker::blocks(const QString &host, const QString &pageHost) const
{
    if (matches(m_allow, host))
        return false;
    if (matches(m_block, host))
        return true;
    // Third-party = the request goes to a different site than the page.
    // shortcut: "same site" = same last two labels, so co.uk-style domains count as one site.
    const auto site = [](const QString &h) { return h.section(QLatin1Char('.'), -2); };
    return site(host) != site(pageHost) && matches(m_blockThirdParty, host);
}

bool AdBlocker::isGoogleSignIn(const QUrl &url)
{
    const QString host = url.host().toLower();
    return url.scheme() == QLatin1String("https")
           && (host == QLatin1String("accounts.google.com") || host == QLatin1String("accounts.youtube.com"));
}

QByteArray AdBlocker::userAgentFor(const QUrl &request, const QUrl &page) const
{
    // The sign-in page and everything it loads (scripts from gstatic.com etc.) say the same thing.
    return isGoogleSignIn(request) || isGoogleSignIn(page) ? engineUserAgent : QByteArray();
}

void AdBlocker::interceptRequest(QWebEngineUrlRequestInfo &info)
{
    const QByteArray agent = userAgentFor(info.requestUrl(), info.firstPartyUrl());
    if (!agent.isEmpty())
        info.setHttpHeader(QByteArrayLiteral("User-Agent"), agent);
    const QString pageHost = info.firstPartyUrl().host();
    const qint64 now = m_clock.elapsed();
    if (now - m_lastActivity.value(pageHost, -1000) > 250) {
        m_lastActivity.insert(pageHost, now);
        emit activity(pageHost);
    }
    // Never block the page itself (typing an address on a list still opens it).
    if (!enabled || info.resourceType() == QWebEngineUrlRequestInfo::ResourceTypeMainFrame)
        return;
    if (blocks(info.requestUrl().host().toLower(), pageHost.toLower())) {
        info.block(true);
        ++m_blockedTotal;
        emit blocked(pageHost);
    }
}
