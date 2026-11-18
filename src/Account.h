#pragma once

#include <QDateTime>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include <functional>

class Browser;
class QTcpServer;

// An optional f1int account (Supabase) and end-to-end encrypted sync.
//
// How the password is used: it's stretched on this computer (PBKDF2, 600,000 rounds, salted
// with the email) into two keys. One is sent to Supabase as the sign-in password, so the
// server never sees the real one. The other locks ("wraps") a random sync key. Everything
// synced is encrypted with that sync key (AES-256-GCM) before it leaves the computer; the
// server stores only ciphertext and the wrapped key, neither of which it can open.
// The session (refresh token) and the sync key are kept in the OS keychain.
//
// Forgotten password: Supabase emails a link; afterwards the old sync key can't be unwrapped
// (only the password could), so synced data starts again from this computer.
class Account : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Use Browser.account")
    // signedOut | confirmEmail (sign-up link sent) | resetSent (reset link sent) |
    // newPassword (reset link opened: choose a new password) | needsPassword (sync key
    // changed elsewhere: sign in again) | signedIn
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString message READ message NOTIFY changed)          // the last error or notice, for the user
    Q_PROPERTY(QString email READ email NOTIFY changed)
    Q_PROPERTY(QString username READ username NOTIFY changed)
    Q_PROPERTY(QString avatar READ avatar NOTIFY changed)            // data: URL, or ""
    Q_PROPERTY(QVariantList devices READ devices NOTIFY changed)     // [{ id, name, platform, last_seen, current }]
    Q_PROPERTY(bool syncOn READ syncOn NOTIFY changed)
    Q_PROPERTY(QVariantMap syncKinds READ syncKinds NOTIFY changed)  // kind -> on
    Q_PROPERTY(QString syncStatus READ syncStatus NOTIFY changed)    // idle | syncing | error | off
    Q_PROPERTY(QDateTime lastSync READ lastSync NOTIFY changed)
    Q_PROPERTY(QString lastSyncNote READ lastSyncNote NOTIFY changed)   // conflicts or errors from the last sync

public:
    explicit Account(Browser *browser, QObject *parent = nullptr);

    QString state() const { return m_state; }
    bool busy() const { return m_busy > 0; }
    QString message() const { return m_message; }
    QString email() const { return m_email; }
    QString username() const { return m_username; }
    QString avatar() const { return m_avatar; }
    QVariantList devices() const { return m_devices; }
    bool syncOn() const;
    QVariantMap syncKinds() const;
    QString syncStatus() const { return m_syncStatus; }
    QDateTime lastSync() const { return m_lastSync; }
    QString lastSyncNote() const { return m_lastSyncNote; }

    Q_INVOKABLE void signUp(const QString &email, const QString &password);
    Q_INVOKABLE void signIn(const QString &email, const QString &password);
    Q_INVOKABLE void signOut();
    Q_INVOKABLE void resendConfirmation();
    Q_INVOKABLE void requestReset(const QString &email);
    // The link from a sign-up or reset email, pasted in (when clicking it didn't reach f1int).
    Q_INVOKABLE void useLink(const QString &link);
    Q_INVOKABLE void setNewPassword(const QString &password);            // after a reset link
    Q_INVOKABLE void changePassword(const QString &current, const QString &next);
    Q_INVOKABLE void setUsername(const QString &name);
    Q_INVOKABLE bool setAvatar(const QUrl &image);
    Q_INVOKABLE void clearAvatar();
    Q_INVOKABLE void deleteAccount(const QString &password);
    Q_INVOKABLE void refreshDevices();
    Q_INVOKABLE void renameDevice(const QString &id, const QString &name);
    Q_INVOKABLE void removeDevice(const QString &id);
    Q_INVOKABLE void setSyncOn(bool on);
    Q_INVOKABLE void setSyncKind(const QString &kind, bool on);
    Q_INVOKABLE void syncNow();
    Q_INVOKABLE void clearMessage() { setMessage({}); }

    // Exposed for tests.
    static QByteArray stretch(const QString &email, const QString &password);   // 32-byte master key
    static QString authSecret(const QByteArray &master);                          // what Supabase gets
    static QByteArray wrapKey(const QByteArray &master);

signals:
    void changed();

private:
    using Reply = std::function<void(int status, const QJsonValue &body)>;
    void call(const QString &method, const QString &path, const QJsonValue &body, bool authed, const Reply &done,
              const QByteArray &prefer = {});
    void withFreshToken(const std::function<void()> &next);
    void takeSession(const QJsonObject &session);
    void afterSignIn(bool fresh);
    void unwrapOrCreateSyncKey(bool allowCreate);
    void registerDevice();
    void loadAccountRow();
    void startLinkListener();
    void stopLinkListener();
    void acceptLinkTokens(const QString &fragment);
    void forget(const QString &why);
    void setMessage(const QString &text);
    void setState(const QString &state);
    void work(int delta) { m_busy += delta; emit changed(); }
    QString errorText(int status, const QJsonValue &body) const;

    // ---- sync ----
    QJsonObject localItems(const QString &kind) const;
    void applyItems(const QString &kind, const QJsonObject &items, const QJsonObject &before);
    void syncKind(const QStringList &queue, int attempt);
    QString baseFile(const QString &kind) const;
    QJsonObject loadBase(const QString &kind, qint64 *version) const;
    void saveBase(const QString &kind, const QJsonObject &items, qint64 version) const;
    void finishSync(bool ok);

    Browser *m_browser;
    QNetworkAccessManager m_net;
    QString m_state = QStringLiteral("signedOut");
    int m_busy = 0;
    QString m_message;
    QString m_email, m_username, m_avatar, m_userId, m_deviceId;
    QByteArray m_access, m_refresh;   // session tokens (refresh token also in the keychain)
    qint64 m_accessExpires = 0;
    QByteArray m_syncKey;             // only while signed in
    QByteArray m_pendingMaster;       // between sign-up and the confirmation link
    QVariantList m_devices;
    QString m_syncStatus = QStringLiteral("off");
    QDateTime m_lastSync;
    QString m_lastSyncNote;
    QStringList m_syncConflicts;
    bool m_syncing = false;
    QTimer m_autoSync, m_soonSync;
    QPointer<QTcpServer> m_listener;
};
