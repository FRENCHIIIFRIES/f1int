#include "Browser.h"
#include "UrlInput.h"

#include <QCoreApplication>

Browser::Browser(QObject *parent)
    : QObject(parent), m_profile(new QQuickWebEngineProfile(this))
{
    // One shared profile for all normal tabs, saved on disk (cookies, cache, site logins).
    // A named profile is saved; an unnamed one would be thrown away on exit.
    // Incognito windows will get their own unnamed profile in Stage 1d.
    m_profile->setStorageName(QStringLiteral("Default"));
    m_profile->setOffTheRecord(false);
}

QUrl Browser::homeUrl() const
{
    // Becomes internal://newtab in Stage 4.
    return m_settings.value(QStringLiteral("home/url"), QStringLiteral("https://duckduckgo.com")).toUrl();
}

QUrl Browser::startUrl() const
{
    // "f1int.exe example.com" opens example.com. Arguments starting with "-" are
    // options (Qt and Chromium accept some), so skip those.
    const QStringList args = QCoreApplication::arguments().mid(1);
    for (const QString &arg : args) {
        if (!arg.startsWith(QLatin1Char('-')))
            return urlFromInput(arg);
    }
    return homeUrl();
}

QUrl Browser::urlFromInput(const QString &text) const
{
    // The search engine becomes a choice in Settings in Stage 1d.
    const QString search = m_settings.value(QStringLiteral("search/template"),
                                            QStringLiteral("https://duckduckgo.com/?q=%s")).toString();
    return ::urlFromInput(text, search);
}
