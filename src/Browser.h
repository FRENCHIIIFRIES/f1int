#pragma once

#include <QObject>
#include <QSettings>
#include <QUrl>
#include <QtQml/qqmlregistration.h>
#include <QtWebEngineQuick/QQuickWebEngineProfile>

// The browser's C++ side, shared by all windows. QML sees it as the "Browser" singleton.
// Later stages add tabs, history, bookmarks, ad blocking etc. here.
class Browser : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QQuickWebEngineProfile *profile READ profile CONSTANT)
    Q_PROPERTY(QUrl homeUrl READ homeUrl CONSTANT)
    Q_PROPERTY(QUrl startUrl READ startUrl CONSTANT)

public:
    explicit Browser(QObject *parent = nullptr);

    QQuickWebEngineProfile *profile() const { return m_profile; }
    QUrl homeUrl() const;
    QUrl startUrl() const;   // a URL given on the command line, or the home page

    // Address bar text -> URL to open (a web address, or a search).
    Q_INVOKABLE QUrl urlFromInput(const QString &text) const;

private:
    QQuickWebEngineProfile *m_profile;
    QSettings m_settings;   // stored in the Windows registry / macOS preferences
};
