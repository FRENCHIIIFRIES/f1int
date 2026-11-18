#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class QNetworkReply;

// Keeps f1int up to date from its GitHub releases (FRENCHIIIFRIES/f1int).
// Checks once a day (or when asked), downloads the new version's .zip, checks it against
// the SHA-256 fingerprint published with the release, then, when you say so, closes
// f1int, puts the new files in place and starts it again. Only GitHub's own hosts are
// used. Windows only for now (macOS updates come as a new .dmg to install).
class Updater : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Use Browser.updater")
    // idle | checking | upToDate | available | downloading | ready | error | unsupported
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString current READ current CONSTANT)
    Q_PROPERTY(QString latest READ latest NOTIFY changed)
    Q_PROPERTY(QString notes READ notes NOTIFY changed)        // what's new, from the release
    Q_PROPERTY(qreal progress READ progress NOTIFY changed)    // 0..1 while downloading
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(bool supported READ supported CONSTANT)          // an installed copy that can update itself

public:
    explicit Updater(QObject *parent = nullptr);

    QString state() const { return m_state; }
    QString current() const;
    QString latest() const { return m_latest; }
    QString notes() const { return m_notes; }
    qreal progress() const { return m_progress; }
    QString error() const { return m_error; }
    bool supported() const;

    Q_INVOKABLE void check();       // asks GitHub
    Q_INVOKABLE void download();    // gets and checks the new version
    Q_INVOKABLE void install();     // closes f1int, updates, restarts

    // "0.2.0" is newer than "0.1.9"; tags may start with "v". Exposed for tests.
    static bool isNewer(const QString &tag, const QString &than);
    static bool trustedHost(const QUrl &url);

signals:
    void changed();

private:
    void fail(const QString &why);
    void set(const QString &state) { m_state = state; emit changed(); }
    QNetworkRequest request(const QUrl &url) const;

    QNetworkAccessManager m_net;
    QTimer m_daily;
    QString m_state = QStringLiteral("idle");
    QString m_latest, m_notes, m_error;
    QUrl m_zipUrl, m_sumsUrl;
    QString m_zipName, m_zipFile;
    qreal m_progress = 0;
    QPointer<QNetworkReply> m_reply;
};
