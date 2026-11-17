#pragma once

#include <QCoreApplication>
#include <QList>
#include <QColor>
#include <QObject>
#include <QPointer>
#include <QSettings>
#include <QTimer>
#include <QUrl>
#include <QtQml/qqmlregistration.h>
#include <QtWebEngineQuick/QQuickWebEngineProfile>
#include "AdBlocker.h"
#include "Library.h"
#include "PasswordVault.h"
#include "TabModel.h"
#include <QQuickWindow>

// The browser's C++ side, shared by all windows. QML sees it as the "Browser" singleton.
// Owns the shared profile, bookmarks/history, the ad blocker and the saved session.
class Browser : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QQuickWebEngineProfile *profile READ profile CONSTANT)
    Q_PROPERTY(Library *library READ library CONSTANT)
    Q_PROPERTY(QUrl homeUrl READ homeUrl NOTIFY settingChanged)
    Q_PROPERTY(bool reduceMotion READ reduceMotion CONSTANT)
    Q_PROPERTY(QUrl uiTestScript READ uiTestScript CONSTANT)
    Q_PROPERTY(int blockedTotal READ blockedTotal NOTIFY blockedChanged)
    Q_PROPERTY(QVariantList searchEngines READ searchEngines CONSTANT)
    // Goes up on every setting change; QML reads it so bindings using settings refresh.
    Q_PROPERTY(int settingsRevision READ settingsRevision NOTIFY settingChanged)
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(PasswordVault *passwords READ passwords CONSTANT)
    // Messages from the password page script start with this (includes a random secret).
    Q_PROPERTY(QString passwordMessagePrefix READ passwordMessagePrefix CONSTANT)
    Q_PROPERTY(QString passwordScript READ passwordScript CONSTANT)

public:
    explicit Browser(QObject *parent = nullptr);

    QQuickWebEngineProfile *profile() const { return m_profile; }
    Library *library() const { return m_library; }
    QUrl homeUrl() const;
    bool reduceMotion() const;   // the system's "show animations" setting is off
    int blockedTotal() const { return m_adBlocker->blockedTotal(); }
    QVariantList searchEngines() const;
    // A QML test script to run inside the app (developers only; set F1INT_UI_TEST=<file>).
    QUrl uiTestScript() const;

    int settingsRevision() const { return m_settingsRevision; }
    PasswordVault *passwords() const { return m_vault; }
    QString passwordMessagePrefix() const { return QStringLiteral("f1int:") + m_nonce + QLatin1Char(':'); }
    QString passwordScript() const;
    // A page helper from resources/scripts (media, reader), with the message secret filled in.
    Q_INVOKABLE QString script(const QString &name) const;

    // Windows Hello / Touch ID. `purpose` "unlock" opens the vault; "verify" re-confirms it's
    // you (to show a password). The answer comes back through deviceAuthFinished.
    Q_INVOKABLE void askDevice(QQuickWindow *window, const QString &purpose);

    // Windows 11: frosted-glass ("acrylic") window background, light or dark.
    // Returns false where it isn't available (the window then uses a solid colour).
    Q_INVOKABLE bool applyBackdrop(QQuickWindow *window, bool dark);
    // Windows 11: colour the title bar to match f1int (caption, title text, dark-mode buttons).
    // Small text files the user picked in a file dialog (theme files, backups). Max 5 MB.
    Q_INVOKABLE QString readTextFile(const QUrl &file) const;
    // Backups: your settings (not passwords, not window state), and restoring them.
    Q_INVOKABLE QVariantMap settingsForBackup() const;
    Q_INVOKABLE int restoreSettings(const QVariantMap &values);
    Q_INVOKABLE bool writeTextFile(const QUrl &file, const QString &text) const;
    Q_INVOKABLE void applyFrameColors(QQuickWindow *window, const QColor &caption, const QColor &text, bool dark);
    QString version() const { return QCoreApplication::applicationVersion(); }

    // Address bar text -> URL to open (a web address, or a search).
    Q_INVOKABLE QUrl urlFromInput(const QString &text) const;
    Q_INVOKABLE QString localPath(const QUrl &fileUrl) const { return fileUrl.toLocalFile(); }
    Q_INVOKABLE QUrl fileUrl(const QString &path) const { return QUrl::fromLocalFile(path); }

    // Saved preferences. Keys look like "group/name", e.g. "tabbar/width".
    Q_INVOKABLE QVariant setting(const QString &key, const QVariant &fallback = {}) const;
    Q_INVOKABLE void setSetting(const QString &key, const QVariant &value);
    Q_INVOKABLE void resetSetting(const QString &key);   // back to the default

    // ---- windows and sessions ----
    Q_INVOKABLE void newWindow(bool incognito = false);
    // A window announces its tab list. Normal windows are saved for session restore;
    // returns true if saved tabs were put into `tabs` (the window then opens nothing else).
    Q_INVOKABLE bool registerWindow(TabModel *tabs, bool incognito);
    Q_INVOKABLE void unregisterWindow(TabModel *tabs);
    // { first: is this the first window?, urls: URLs given on the command line (first window only) }
    Q_INVOKABLE QVariantMap takeStartUrls();
    // A throwaway profile for an incognito window: nothing is written to disk.
    Q_INVOKABLE QQuickWebEngineProfile *createIncognitoProfile(QObject *window);

    // ---- privacy and memory ----
    Q_INVOKABLE void clearBrowsingData();   // history, cookies, cache
    // { total, browser, processes: { "<pid>": bytes } } for internal memory stats.
    Q_INVOKABLE QVariantMap memoryInfo() const;
    // { percent (-1 = no battery / unknown), charging } for the new tab page.
    Q_INVOKABLE QVariantMap battery() const;

signals:
    void settingChanged();
    void blockedChanged();
    void siteActivity(const QString &host);   // a page on `host` is sending requests
    void deviceAuthFinished(const QString &purpose, bool ok, const QString &error);

private:
    void setUpProfile(QQuickWebEngineProfile *profile);
    void applyColorScheme();   // light/dark window frame to match the theme setting
    void scheduleSave();
    void writeSession();
    void loadFilterLists();

    QQuickWebEngineProfile *m_profile;
    Library *m_library;
    AdBlocker *m_adBlocker;
    PasswordVault *m_vault;
    QString m_nonce;
    QSettings m_settings;   // stored in the Windows registry / macOS preferences
    QString m_dataDir;
    QList<QPointer<TabModel>> m_windows;       // normal windows, in opening order
    QList<QJsonObject> m_pendingRestore;       // saved windows not yet reopened
    bool m_startUrlsTaken = false;
    int m_settingsRevision = 0;
    QTimer m_saveTimer;
};
