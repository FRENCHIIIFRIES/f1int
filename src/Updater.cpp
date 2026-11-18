#include "Updater.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QVersionNumber>

static const QString kReleases = QStringLiteral("https://api.github.com/repos/FRENCHIIIFRIES/f1int/releases?per_page=10");

Updater::Updater(QObject *parent) : QObject(parent)
{
    if (!supported()) {
        m_state = QStringLiteral("unsupported");
        return;
    }
    // Once a day, starting a minute after f1int opens (if automatic checks are on).
    m_daily.setInterval(24 * 60 * 60 * 1000);
    connect(&m_daily, &QTimer::timeout, this, &Updater::check);
    const bool automatic = QSettings().value(QStringLiteral("updates/auto"), true).toString() != QLatin1String("false");
    if (automatic && !qEnvironmentVariableIsSet("F1INT_UI_TEST")) {
        m_daily.start();
        QTimer::singleShot(60 * 1000, this, &Updater::check);
    }
}

QString Updater::current() const { return QCoreApplication::applicationVersion(); }

bool Updater::supported() const
{
#ifdef Q_OS_WIN
    // An installed copy: f1int.exe in "bin" next to the licence notices (not a developer build).
    const QDir bin(QCoreApplication::applicationDirPath());
    return bin.dirName() == QLatin1String("bin") && QFile::exists(bin.filePath(QStringLiteral("../THIRD_PARTY_NOTICES.md")));
#else
    return false;   // shortcut: macOS updates need replacing the .app bundle; until then, a new .dmg
#endif
}

bool Updater::isNewer(const QString &tag, const QString &than)
{
    const auto parse = [](QString v) { if (v.startsWith(QLatin1Char('v'))) v.remove(0, 1); return QVersionNumber::fromString(v); };
    const QVersionNumber a = parse(tag), b = parse(than);
    return !a.isNull() && QVersionNumber::compare(a, b) > 0;
}

bool Updater::trustedHost(const QUrl &url)
{
    const QString host = url.host();
    return url.scheme() == QLatin1String("https")
           && (host == QLatin1String("api.github.com") || host == QLatin1String("github.com")
               || host == QLatin1String("objects.githubusercontent.com") || host == QLatin1String("release-assets.githubusercontent.com"));
}

QNetworkRequest Updater::request(const QUrl &url) const
{
    QNetworkRequest req(url);
    req.setRawHeader("User-Agent", "f1int-updater");   // GitHub asks for one; nothing about you is sent
    req.setRawHeader("Accept", "application/octet-stream, application/json");
    req.setTransferTimeout(60000);
    // Follow GitHub's redirects to its download servers, but nowhere else.
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::UserVerifiedRedirectPolicy);
    return req;
}

void Updater::fail(const QString &why)
{
    m_error = why;
    set(QStringLiteral("error"));
}

void Updater::check()
{
    if (!supported() || m_state == QLatin1String("checking") || m_state == QLatin1String("downloading") || m_state == QLatin1String("ready"))
        return;
    set(QStringLiteral("checking"));
    QNetworkReply *reply = m_net.get(request(QUrl(kReleases)));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError)
            return fail(tr("Couldn't check for updates: %1").arg(reply->errorString()));
        // The newest published release (previews count: f1int is in 0.x).
        for (const QJsonValue &v : QJsonDocument::fromJson(reply->readAll()).array()) {
            const QJsonObject r = v.toObject();
            if (r["draft"].toBool())
                continue;
            const QString tag = r["tag_name"].toString();
            if (!isNewer(tag, current()))
                break;
            m_zipUrl.clear();
            m_sumsUrl.clear();
            for (const QJsonValue &a : r["assets"].toArray()) {
                const QString name = a.toObject()["name"].toString();
                const QUrl url(a.toObject()["browser_download_url"].toString());
                if (name.endsWith(QLatin1String("-windows-x64.zip")) && trustedHost(url)) { m_zipUrl = url; m_zipName = name; }
                if (name == QLatin1String("SHA256SUMS.txt") && trustedHost(url)) m_sumsUrl = url;
            }
            if (m_zipUrl.isEmpty() || m_sumsUrl.isEmpty())
                continue;   // a release without a Windows update package: look at the one before
            m_latest = tag.startsWith(QLatin1Char('v')) ? tag.mid(1) : tag;
            m_notes = r["body"].toString().left(2000);
            return set(QStringLiteral("available"));
        }
        set(QStringLiteral("upToDate"));
    });
}

void Updater::download()
{
    if (m_state != QLatin1String("available"))
        return;
    m_progress = 0;
    set(QStringLiteral("downloading"));
    // First the fingerprints, then the package.
    QNetworkReply *sums = m_net.get(request(m_sumsUrl));
    connect(sums, &QNetworkReply::redirected, sums, [sums](const QUrl &to) { if (trustedHost(to)) emit sums->redirectAllowed(); });
    connect(sums, &QNetworkReply::finished, this, [this, sums] {
        sums->deleteLater();
        if (sums->error() != QNetworkReply::NoError)
            return fail(tr("Couldn't download the update: %1").arg(sums->errorString()));
        QByteArray expected;
        for (const QByteArray &line : sums->readAll().split('\n')) {   // "<sha256>  <file name>"
            const QList<QByteArray> parts = line.simplified().split(' ');
            if (parts.size() == 2 && QString::fromLatin1(parts[1]).remove(QLatin1Char('*')) == m_zipName)
                expected = parts[0].toLower();
        }
        if (expected.size() != 64)
            return fail(tr("The update has no fingerprint to check it against, so it wasn't installed."));

        m_zipFile = QDir::temp().filePath(m_zipName);
        auto *file = new QFile(m_zipFile, this);
        if (!file->open(QIODevice::WriteOnly))
            return fail(tr("Couldn't save the update."));
        auto *hash = new QCryptographicHash(QCryptographicHash::Sha256);
        m_reply = m_net.get(request(m_zipUrl));
        QNetworkReply *reply = m_reply;
        connect(reply, &QNetworkReply::redirected, reply, [reply](const QUrl &to) { if (trustedHost(to)) emit reply->redirectAllowed(); });
        connect(reply, &QNetworkReply::readyRead, this, [reply, file, hash] {
            const QByteArray chunk = reply->readAll();
            hash->addData(chunk);
            file->write(chunk);
        });
        connect(reply, &QNetworkReply::downloadProgress, this, [this](qint64 got, qint64 total) {
            m_progress = total > 0 ? qreal(got) / total : 0;
            emit changed();
        });
        connect(reply, &QNetworkReply::finished, this, [this, reply, file, hash, expected] {
            reply->deleteLater();
            file->write(reply->readAll());
            hash->addData(QByteArray());
            const QByteArray got = hash->result().toHex();
            file->close();
            file->deleteLater();
            delete hash;
            if (reply->error() != QNetworkReply::NoError) {
                QFile::remove(m_zipFile);
                return fail(tr("Couldn't download the update: %1").arg(reply->errorString()));
            }
            if (got != expected) {
                QFile::remove(m_zipFile);
                return fail(tr("The download didn't match its fingerprint, so it was thrown away. Try again later."));
            }
            set(QStringLiteral("ready"));
        });
    });
}

void Updater::install()
{
#ifdef Q_OS_WIN
    if (m_state != QLatin1String("ready") || !QFile::exists(m_zipFile))
        return;
    // f1int can't replace itself while it runs, so a small PowerShell script (part of
    // Windows) waits for it to close, unpacks the update over the install folder and
    // starts the new f1int. Paths are passed as arguments, never pasted into the script.
    const QString root = QDir(QCoreApplication::applicationDirPath() + QStringLiteral("/..")).absolutePath();
    const QString script = QDir::temp().filePath(QStringLiteral("f1int-update.ps1"));
    QFile f(script);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return fail(tr("Couldn't prepare the update."));
    f.write(R"PS(param([int]$AppPid, [string]$Zip, [string]$Root)
$ErrorActionPreference = 'Stop'
try { Wait-Process -Id $AppPid -Timeout 60 -ErrorAction SilentlyContinue } catch {}
$tmp = Join-Path $env:TEMP ('f1int-update-' + [guid]::NewGuid())
Expand-Archive -LiteralPath $Zip -DestinationPath $tmp -Force
$src = Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1
if (-not (Test-Path (Join-Path $src.FullName 'bin\f1int.exe'))) { throw 'not an f1int package' }
for ($i = 0; $i -lt 10; $i++) {
  try { Copy-Item -Path (Join-Path $src.FullName '*') -Destination $Root -Recurse -Force; break } catch { Start-Sleep -Seconds 1 }
}
Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $Zip -Force -ErrorAction SilentlyContinue
Start-Process (Join-Path $Root 'bin\f1int.exe')
)PS");
    f.close();
    const bool started = QProcess::startDetached(QStringLiteral("powershell.exe"),
        { QStringLiteral("-NoProfile"), QStringLiteral("-ExecutionPolicy"), QStringLiteral("Bypass"), QStringLiteral("-WindowStyle"), QStringLiteral("Hidden"),
          QStringLiteral("-File"), script, QStringLiteral("-AppPid"), QString::number(QCoreApplication::applicationPid()),
          QStringLiteral("-Zip"), m_zipFile, QStringLiteral("-Root"), root });
    if (!started)
        return fail(tr("Couldn't start the update."));
    QCoreApplication::quit();   // your tabs are saved and come back after the restart
#endif
}
