#pragma once

#include <QObject>
#include <QSettings>
#include <QUrl>
#include <QtQml/qqmlregistration.h>
#include <QtWebEngineQuick/QQuickWebEngineProfile>
#include "TabModel.h"

// The browser's C++ side, shared by all windows. QML sees it as the "Browser" singleton.
// Later stages add tabs, history, bookmarks, ad blocking etc. here.
class Browser : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QQuickWebEngineProfile *profile READ profile CONSTANT)
    Q_PROPERTY(QUrl homeUrl READ homeUrl CONSTANT)
    Q_PROPERTY(QList<QUrl> startUrls READ startUrls CONSTANT)
    Q_PROPERTY(TabModel *tabs READ tabs CONSTANT)
    Q_PROPERTY(bool reduceMotion READ reduceMotion CONSTANT)
    Q_PROPERTY(QUrl uiTestScript READ uiTestScript CONSTANT)

public:
    explicit Browser(QObject *parent = nullptr);

    QQuickWebEngineProfile *profile() const { return m_profile; }
    TabModel *tabs() const { return m_tabs; }
    QUrl homeUrl() const;
    QList<QUrl> startUrls() const;   // URLs given on the command line (one tab each), or the home page
    bool reduceMotion() const;   // the system's "show animations" setting is off
    // A QML test script to run inside the app (developers only; set F1INT_UI_TEST=<file>).
    QUrl uiTestScript() const { return QUrl::fromLocalFile(qEnvironmentVariable("F1INT_UI_TEST")); }

    // Address bar text -> URL to open (a web address, or a search).
    Q_INVOKABLE QUrl urlFromInput(const QString &text) const;

    // Small saved preferences (tab bar width, collapsed, ...).
    Q_INVOKABLE QVariant setting(const QString &key, const QVariant &fallback = {}) const;
    Q_INVOKABLE void setSetting(const QString &key, const QVariant &value);

private:
    QQuickWebEngineProfile *m_profile;
    TabModel *m_tabs;
    QSettings m_settings;   // stored in the Windows registry / macOS preferences
};
