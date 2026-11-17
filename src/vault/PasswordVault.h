#pragma once

#include <QByteArray>
#include <QJsonObject>
#include <QList>
#include <QObject>
#include <QTimer>
#include <QUrl>
#include <QVariantList>

// The password manager's vault: saved logins, encrypted on disk, never sent anywhere.
//
// How it is locked:
//  - The logins are encrypted with AES-256-GCM using a random 256-bit "vault key".
//  - The vault key is itself encrypted with a key made from your master password
//    (PBKDF2-SHA256, 600 000 rounds), and stored next to the logins.
//  - Optionally the vault key is also kept in the OS keychain (Windows Credential Manager /
//    macOS Keychain), so you can unlock with Windows Hello / Touch ID instead of typing.
// While unlocked, the logins are in memory; locking wipes them.
class PasswordVault : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY changed)          // "none" (not set up) | "locked" | "unlocked"
    Q_PROPERTY(int revision READ revision NOTIFY changed)        // goes up on every change (QML refresh)
    Q_PROPERTY(bool deviceUnlock READ deviceUnlock NOTIFY changed)
    Q_PROPERTY(int autoLockMinutes MEMBER m_autoLockMinutes)

public:
    explicit PasswordVault(const QString &filePath, const QString &keychainName = QStringLiteral("vault-key"),
                           QObject *parent = nullptr);
    ~PasswordVault() override;

    QString state() const;
    int revision() const { return m_revision; }
    bool deviceUnlock() const { return m_header.value(QStringLiteral("device")).toBool(); }

    // ---- locking ----
    Q_INVOKABLE bool setUp(const QString &master, bool deviceUnlock);   // create a new vault
    Q_INVOKABLE bool unlock(const QString &master);
    bool unlockWithKeychain();             // call after Windows Hello / Touch ID said yes
    Q_INVOKABLE void lock();
    Q_INVOKABLE bool verify(const QString &master);   // confirm it's you again (to view a password)
    void markVerified();                   // ... or after a device check
    Q_INVOKABLE bool recentlyVerified() const;        // within the last minute
    Q_INVOKABLE void setDeviceUnlock(bool on);
    Q_INVOKABLE void forgetVault();        // deletes the vault file and keychain entry

    // ---- logins (only while unlocked) ----
    Q_INVOKABLE QVariantList loginsFor(const QUrl &page) const;          // [{ id, username }]
    Q_INVOKABLE QVariantList entries(const QString &filter = {}) const;  // no passwords; with weak/reused flags
    Q_INVOKABLE QString password(const QString &id) const;              // for autofill
    Q_INVOKABLE QString reveal(const QString &id) const;                // for showing; needs recentlyVerified()
    // "new", "update" (same user, other password) or "same": what saving would do.
    Q_INVOKABLE QString saveKind(const QUrl &page, const QString &username, const QString &password) const;
    Q_INVOKABLE QString save(const QUrl &page, const QString &username, const QString &password);
    Q_INVOKABLE void edit(const QString &id, const QString &origin, const QString &username, const QString &password);
    Q_INVOKABLE void remove(const QString &id);
    Q_INVOKABLE void copy(const QString &id, const QString &field);     // "username" | "password"; cleared after 30 s
    Q_INVOKABLE QVariantMap health() const;                             // { weak, reused }

    // ---- import / export ----
    Q_INVOKABLE int importCsv(const QUrl &file);       // Google Password Manager / Chrome / Firefox CSV
    Q_INVOKABLE bool exportCsv(const QUrl &file) const;

    // ---- helpers ----
    Q_INVOKABLE static QString generate(int length = 20);   // strong random password
    Q_INVOKABLE static bool isWeak(const QString &password);
    static QString originOf(const QUrl &url);               // "https://example.com"
    static QList<QStringList> parseCsv(const QByteArray &data);

signals:
    void changed();

private:
    struct Entry {
        QString id, origin, username, password, note;
        qint64 created = 0, updated = 0;
    };
    bool readHeader();
    bool openWith(QByteArray vaultKey);
    bool write();
    void touch();                     // restart the auto-lock timer
    const Entry *find(const QString &id) const;
    static bool sameSite(const QString &origin, const QUrl &page);

    QString m_path;
    QString m_keychainName;
    QJsonObject m_header;             // salt, iterations, wrapped key, device flag, encrypted data
    QByteArray m_key;                 // vault key, only while unlocked
    QList<Entry> m_entries;           // only while unlocked
    qint64 m_verifiedAt = 0;
    int m_revision = 0;
    int m_autoLockMinutes = 15;
    QTimer m_autoLock;
};
