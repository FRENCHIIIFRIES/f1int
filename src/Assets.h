#pragma once

#include <QObject>
#include <QQuickImageProvider>
#include <QUrl>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Your own pictures, patterns, icons and loading animations, for themes.
// Every file is checked before f1int keeps a copy: pictures are decoded and saved again
// (which drops anything hidden in the file), SVG drawings go through an allow-list that
// removes scripts, event handlers and links to other files or sites. Nothing uploaded is
// ever run. Copies live in the profile's "assets" folder, named by their content.
class Assets : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Use Browser.assets")
    Q_PROPERTY(QStringList iconNames READ iconNames CONSTANT)   // f1int's own icons, which a pack can replace

public:
    explicit Assets(const QString &dir, QObject *parent = nullptr);

    // kind: "image" (wallpapers, backgrounds, patterns), "icon" (an SVG), "loader" (may be animated).
    // Returns { ok, id, url, error }.
    Q_INVOKABLE QVariantMap add(const QUrl &file, const QString &kind);
    Q_INVOKABLE QVariantMap addData(const QByteArray &data, const QString &fileName, const QString &kind);
    Q_INVOKABLE QVariantMap addBase64(const QString &base64, const QString &fileName, const QString &kind)
    {
        return addData(QByteArray::fromBase64(base64.toLatin1()), fileName, kind);   // (theme files carry assets as text)
    }
    // Several SVGs named like f1int's icons ("star.svg", "home.svg"...): { icons: {name: id}, added, skipped }.
    Q_INVOKABLE QVariantMap addIcons(const QList<QUrl> &files);
    Q_INVOKABLE QUrl url(const QString &id) const;           // empty if it isn't a stored asset
    Q_INVOKABLE QString base64(const QString &id) const;      // for theme files
    Q_INVOKABLE bool isAnimated(const QString &id) const;
    QString path(const QString &id) const;                    // empty if `id` isn't valid

    QStringList iconNames() const;
    // An SVG with anything that could run or fetch removed; empty (and `error` set) if it isn't a usable SVG.
    static QByteArray cleanSvg(const QByteArray &svg, QString *error = nullptr);

private:
    QVariantMap store(const QByteArray &bytes, const QString &ext);
    QString m_dir;
};

// image://icons/<name>?w=<stroke width>  or  image://icons/asset/<id>
// Draws f1int's icons at any stroke weight, or an icon from a pack, at the size asked for.
class IconProvider : public QQuickImageProvider
{
public:
    explicit IconProvider(Assets *assets) : QQuickImageProvider(QQuickImageProvider::Image), m_assets(assets) {}
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    Assets *m_assets;
};
