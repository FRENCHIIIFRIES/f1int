#include "Browser.h"
#include "UrlInput.h"

#include <QCoreApplication>
#ifdef Q_OS_WIN
#define NOMINMAX   // stop windows.h from defining min/max macros that clash with Qt
#include <windows.h>
#endif

Browser::Browser(QObject *parent)
    : QObject(parent), m_profile(new QQuickWebEngineProfile(this)), m_tabs(new TabModel(this))
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
    return m_settings.value(QStringLiteral("home/url"), QStringLiteral("https://www.google.com")).toUrl();
}

QList<QUrl> Browser::startUrls() const
{
    // "f1int.exe example.com news.test" opens two tabs. Arguments starting with "-" are
    // options (Qt and Chromium accept some), so skip those.
    QList<QUrl> urls;
    const QStringList args = QCoreApplication::arguments().mid(1);
    for (const QString &arg : args) {
        if (!arg.startsWith(QLatin1Char('-')))
            urls.append(urlFromInput(arg));
    }
    return urls.isEmpty() ? QList<QUrl>{ homeUrl() } : urls;
}

bool Browser::reduceMotion() const
{
#ifdef Q_OS_WIN
    // Settings > Accessibility > Visual effects > "Animation effects"
    BOOL animations = TRUE;
    SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &animations, 0);
    return !animations;
#else
    return false;   // macOS check comes with the Mac polish pass
#endif
}

QVariant Browser::setting(const QString &key, const QVariant &fallback) const
{
    return m_settings.value(key, fallback);
}

void Browser::setSetting(const QString &key, const QVariant &value)
{
    m_settings.setValue(key, value);
}

QUrl Browser::urlFromInput(const QString &text) const
{
    // The search engine becomes a choice in Settings in Stage 1d.
    const QString search = m_settings.value(QStringLiteral("search/template"),
                                            QStringLiteral("https://www.google.com/search?q=%s")).toString();
    return ::urlFromInput(text, search);
}
