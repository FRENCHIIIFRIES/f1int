#include "Favicons.h"

#include <QDir>
#include <QFile>
#include <QImage>
#include <QNetworkReply>
#include <QRegularExpression>

Favicons::Favicons(const QString &dir, QObject *parent) : QObject(parent), m_dir(dir)
{
    QDir().mkpath(m_dir);
}

QString Favicons::keyFor(const QUrl &page)
{
    if (page.scheme() != QLatin1String("http") && page.scheme() != QLatin1String("https"))
        return {};
    QString host = page.host().toLower();
    if (host.startsWith(QLatin1String("www.")))
        host.remove(0, 4);
    static const QRegularExpression safe(QStringLiteral("^[a-z0-9.-]{1,200}$"));   // also a safe file name
    return safe.match(host).hasMatch() ? host : QString();
}

QUrl Favicons::icon(const QUrl &page)
{
    const QString key = keyFor(page);
    if (key.isEmpty())
        return {};
    if (QFile::exists(file(key)))
        return QUrl::fromLocalFile(file(key));
    if (!m_tried.contains(key)) {
        m_tried.insert(key);
        QUrl root;
        root.setScheme(page.scheme());
        root.setHost(page.host());
        root.setPath(QStringLiteral("/favicon.ico"));
        fetch(key, root, false);
    }
    return {};
}

void Favicons::pageIcon(const QUrl &page, const QUrl &engineIcon)
{
    const QString key = keyFor(page);
    QString address = engineIcon.toString();
    if (key.isEmpty() || !address.startsWith(QLatin1String("image://favicon/")))
        return;
    address.remove(0, 16);
    const QUrl from(address);
    if (from.scheme() != QLatin1String("https") && from.scheme() != QLatin1String("http"))
        return;   // (data: icons and the like: skip)
    m_tried.insert(key);
    fetch(key, from, true);
}

void Favicons::fetch(const QString &key, const QUrl &from, bool fallback)
{
    QNetworkRequest req(from);
    req.setTransferTimeout(10000);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = m_net.get(req);
    connect(reply, &QNetworkReply::downloadProgress, reply, [reply](qint64 got, qint64) {
        if (got > 1024 * 1024) reply->abort();   // an icon is never this big
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, key, from, fallback] {
        reply->deleteLater();
        QImage image;
        if (reply->error() == QNetworkReply::NoError)
            image.loadFromData(reply->readAll());   // decoded: anything that isn't a picture is dropped
        if (image.isNull()) {
            if (fallback) {   // the page's icon failed: try the site's /favicon.ico once
                QUrl root;
                root.setScheme(from.scheme());
                root.setHost(from.host());
                root.setPath(QStringLiteral("/favicon.ico"));
                if (root != from)
                    fetch(key, root, false);
            }
            return;
        }
        image.scaled(32, 32, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(file(key), "PNG");
        ++m_revision;
        emit changed();
    });
}
