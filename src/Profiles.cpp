#include "Profiles.h"
#include "Keychain.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QUuid>
#include <algorithm>

// The profile list and pictures live outside every profile, shared by all of them.
QString Profiles::family = QStringLiteral("f1int");

static QString sharedDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/f1int/") + Profiles::family + QStringLiteral("-profiles");
}
static QSettings sharedSettings() { return QSettings(QStringLiteral("f1int"), Profiles::family + QStringLiteral("-profiles")); }
// Where a profile keeps its data, worked out from its application name.
static QString dataDirOf(const QString &appName)
{
    QString here = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return here.left(here.lastIndexOf(QLatin1Char('/')) + 1) + appName;
}
static QString cacheDirOf(const QString &appName)
{
    QString here = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    return here.left(here.lastIndexOf(QLatin1Char('/')) + 1) + appName;
}

Profiles::Profiles(const QString &current, QObject *parent)
    : QObject(parent), m_current(current)
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    m_lock = std::make_unique<QLockFile>(dir + QStringLiteral("/running.lock"));
    m_lock->setStaleLockTime(0);   // a crashed run's lock is noticed by its dead process id, not by age
    m_lock->tryLock(100);
}

bool Profiles::validId(const QString &id)
{
    static const QRegularExpression ok(QStringLiteral("^[a-z0-9]{1,24}$"));
    return id.isEmpty() || ok.match(id).hasMatch();
}

QString Profiles::appNameFor(const QString &id)
{
    return id.isEmpty() ? family : family + QStringLiteral("-p-") + id;
}

QVariantList Profiles::stored() const
{
    QVariantList list = QJsonDocument::fromJson(sharedSettings().value(QStringLiteral("list")).toByteArray()).array().toVariantList();
    // The first profile is always there, even before anyone names it.
    if (std::none_of(list.begin(), list.end(), [](const QVariant &p) { return p.toMap()["id"].toString().isEmpty(); }))
        list.prepend(QVariantMap{ { "id", QString() }, { "name", tr("Personal") } });
    return list;
}

void Profiles::store(const QVariantList &list)
{
    sharedSettings().setValue(QStringLiteral("list"), QJsonDocument(QJsonArray::fromVariantList(list)).toJson(QJsonDocument::Compact));
    ++m_revision;
    emit changed();
}

QString Profiles::pictureFile(const QString &id) const
{
    return sharedDir() + QStringLiteral("/") + (id.isEmpty() ? QStringLiteral("first") : id) + QStringLiteral(".png");
}

QVariantList Profiles::list() const
{
    QVariantList out;
    for (const QVariant &v : stored()) {
        QVariantMap p = v.toMap();
        const QString id = p["id"].toString();
        if (!validId(id))
            continue;
        const QString pic = pictureFile(id);
        // "?r=" changes with every edit, so a replaced picture isn't served from the image cache.
        p["picture"] = QFile::exists(pic) ? QUrl::fromLocalFile(pic).toString() + QStringLiteral("?r=%1").arg(m_revision) : QString();
        p["current"] = id == m_current;
        out.append(p);
    }
    return out;
}

QString Profiles::currentName() const
{
    for (const QVariant &v : list())
        if (v.toMap()["current"].toBool())
            return v.toMap()["name"].toString();
    return {};
}

QUrl Profiles::currentPicture() const
{
    for (const QVariant &v : list())
        if (v.toMap()["current"].toBool())
            return QUrl(v.toMap()["picture"].toString());
    return {};
}

QString Profiles::add(const QString &name)
{
    const QString id = QUuid::createUuid().toString(QUuid::Id128).left(10);
    QVariantList l = stored();
    l.append(QVariantMap{ { "id", id }, { "name", name.trimmed().left(40).isEmpty() ? tr("Profile %1").arg(l.size() + 1) : name.trimmed().left(40) } });
    store(l);
    return id;
}

void Profiles::rename(const QString &id, const QString &name)
{
    const QString clean = name.trimmed().left(40);
    if (clean.isEmpty())
        return;
    QVariantList l = stored();
    for (QVariant &v : l) {
        QVariantMap p = v.toMap();
        if (p["id"].toString() == id) { p["name"] = clean; v = p; }
    }
    store(l);
}

bool Profiles::setPicture(const QString &id, const QUrl &image)
{
    QImage img(image.toLocalFile());   // only real images load: anything else is refused
    if (!validId(id) || img.isNull())
        return false;
    const int side = std::min(img.width(), img.height());
    img = img.copy((img.width() - side) / 2, (img.height() - side) / 2, side, side)
             .scaled(256, 256, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    QImage round(256, 256, QImage::Format_ARGB32_Premultiplied);   // saved already round: the UI just shows it
    round.fill(Qt::transparent);
    QPainter painter(&round);
    painter.setRenderHint(QPainter::Antialiasing);
    QPainterPath circle;
    circle.addEllipse(0, 0, 256, 256);
    painter.setClipPath(circle);
    painter.drawImage(0, 0, img);
    painter.end();
    QDir().mkpath(sharedDir());
    const bool ok = round.save(pictureFile(id), "PNG");
    store(stored());   // tell everyone the picture changed
    return ok;
}

void Profiles::clearPicture(const QString &id)
{
    if (validId(id))
        QFile::remove(pictureFile(id));
    store(stored());
}

bool Profiles::open(const QString &id)
{
    if (!validId(id))
        return false;
    return QProcess::startDetached(QCoreApplication::applicationFilePath(),
                                   { QStringLiteral("--profile=") + (id.isEmpty() ? QStringLiteral("first") : id) });
}

QString Profiles::remove(const QString &id)
{
    if (id.isEmpty() || !validId(id))
        return tr("The first profile can't be deleted.");
    if (id == m_current)
        return tr("Switch to another profile to delete this one.");
    const QString app = appNameFor(id);
    QLockFile running(dataDirOf(app) + QStringLiteral("/running.lock"));
    // Only "someone else holds it" means open: a profile never opened has no folder to lock in.
    if (!running.tryLock(0) && running.error() == QLockFile::LockFailedError)
        return tr("That profile is open. Close its windows first.");
    running.unlock();

    QDir(dataDirOf(app)).removeRecursively();       // bookmarks, history, passwords, web storage
    QDir(cacheDirOf(app)).removeRecursively();
    QSettings(QStringLiteral("f1int"), app).clear();  // its settings
    Keychain::remove(app + QStringLiteral("-vault-key"));
    QFile::remove(pictureFile(id));
    QVariantList l = stored();
    l.erase(std::remove_if(l.begin(), l.end(), [&](const QVariant &p) { return p.toMap()["id"].toString() == id; }), l.end());
    store(l);
    return {};
}
