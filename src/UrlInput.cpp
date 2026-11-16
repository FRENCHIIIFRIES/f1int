#include "UrlInput.h"

#include <QRegularExpression>

QUrl urlFromInput(const QString &input, const QString &searchTemplate)
{
    const QString text = input.trimmed();
    if (text.isEmpty())
        return {};

    // 1. Typed with a scheme we know ("https://…", "about:blank", "file:///…"): use it as is.
    static const QRegularExpression knownScheme(
        QStringLiteral("^(https?|file|about|data|view-source|internal):"),
        QRegularExpression::CaseInsensitiveOption);
    if (knownScheme.match(text).hasMatch())
        return QUrl(text);

    // 2. One "word" that looks like an address: "example.com/page", "localhost:3000", "10.0.0.1".
    static const QRegularExpression space(QStringLiteral("\\s"));
    if (!text.contains(space)) {
        // The host is everything before the first / ? or #
        QString host = text.left(text.indexOf(QRegularExpression(QStringLiteral("[/?#]"))));

        // Local addresses get http://, because local dev servers rarely have HTTPS.
        static const QRegularExpression ipv4(QStringLiteral("^\\d{1,3}(\\.\\d{1,3}){3}$"));
        if (host.startsWith(QLatin1Char('[')))   // IPv6, e.g. [::1]:8080
            return QUrl(QStringLiteral("http://") + text);
        host = host.section(QLatin1Char(':'), 0, 0).toLower();   // drop ":3000"
        if (host == QLatin1String("localhost") || host.endsWith(QLatin1String(".localhost"))
            || ipv4.match(host).hasMatch())
            return QUrl(QStringLiteral("http://") + text);

        // Everything else needs a dot and a last part made of letters (com, org, рф, xn--…).
        // shortcut: no list of real domain endings, so "node.js" counts as an address.
        // Upgrade to Qt's public-suffix check if that annoys people.
        static const QRegularExpression tld(QStringLiteral("^(\\p{L}{2,63}|xn--[a-z0-9-]+)$"),
                                            QRegularExpression::CaseInsensitiveOption);
        if (host.contains(QLatin1Char('.')) && !host.startsWith(QLatin1Char('.'))
            && !host.contains(QLatin1String("..")) && tld.match(host.section(QLatin1Char('.'), -1)).hasMatch()) {
            const QUrl url(QStringLiteral("https://") + text);   // HTTPS first, like modern browsers
            if (url.isValid())
                return url;
        }
    }

    // 3. Anything else is a search. Percent-encode the query so "&", "#", "+" stay part of it.
    QString search = searchTemplate;
    search.replace(QLatin1String("%s"), QString::fromLatin1(QUrl::toPercentEncoding(text)));
    return QUrl(search);
}
