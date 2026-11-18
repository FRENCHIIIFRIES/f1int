#include "Assets.h"

#include <QBuffer>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImageReader>
#include <QPainter>
#include <QRegularExpression>
#include <QSvgRenderer>
#include <QXmlStreamReader>
#include <QXmlStreamWriter>

// The value of `key` in "a=1&b=2" (no QUrlQuery needed for one value).
static QString QUrlQuery_value(const QString &query, const QString &key)
{
    for (const QString &pair : query.split(QLatin1Char('&')))
        if (pair.section(QLatin1Char('='), 0, 0) == key)
            return pair.section(QLatin1Char('='), 1);
    return {};
}

static const qint64 kMaxImage = 20 * 1024 * 1024;   // a big photo is fine
static const qint64 kMaxIcon = 256 * 1024;
static const qint64 kMaxLoader = 4 * 1024 * 1024;
static const int kMaxSide = 3840;                    // larger wallpapers are scaled down (RAM)

Assets::Assets(const QString &dir, QObject *parent) : QObject(parent), m_dir(dir)
{
    QDir().mkpath(m_dir);
}

QStringList Assets::iconNames() const
{
    QStringList names;
    for (const QString &f : QDir(QStringLiteral(":/icons")).entryList({ QStringLiteral("*.svg") }))
        names << f.chopped(4);
    return names;
}

QString Assets::path(const QString &id) const
{
    static const QRegularExpression ok(QStringLiteral("^[0-9a-f]{20}\\.(png|jpg|svg|gif|webp)$"));
    return ok.match(id).hasMatch() ? m_dir + QLatin1Char('/') + id : QString();
}

QUrl Assets::url(const QString &id) const
{
    const QString p = path(id);
    return !p.isEmpty() && QFile::exists(p) ? QUrl::fromLocalFile(p) : QUrl();
}

QString Assets::base64(const QString &id) const
{
    QFile f(path(id));
    return f.open(QIODevice::ReadOnly) ? QString::fromLatin1(f.readAll().toBase64()) : QString();
}

bool Assets::isAnimated(const QString &id) const
{
    QImageReader r(path(id));
    return r.supportsAnimation() && r.imageCount() > 1;
}

QVariantMap Assets::store(const QByteArray &bytes, const QString &ext)
{
    const QString id = QString::fromLatin1(QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex().left(20)) + QLatin1Char('.') + ext;
    QFile f(m_dir + QLatin1Char('/') + id);
    if (!f.exists() && (!f.open(QIODevice::WriteOnly) || f.write(bytes) != bytes.size()))
        return { { "ok", false }, { "error", tr("Couldn't save the file.") } };
    return { { "ok", true }, { "id", id }, { "url", QUrl::fromLocalFile(f.fileName()) } };
}

QVariantMap Assets::add(const QUrl &file, const QString &kind)
{
    QFile f(file.toLocalFile());
    if (!file.isLocalFile() || !f.open(QIODevice::ReadOnly))
        return { { "ok", false }, { "error", tr("That file couldn't be opened.") } };
    if (f.size() > kMaxImage)
        return { { "ok", false }, { "error", tr("That file is too big (20 MB at most).") } };
    return addData(f.readAll(), QFileInfo(f.fileName()).fileName(), kind);
}

QVariantMap Assets::addData(const QByteArray &data, const QString &fileName, const QString &kind)
{
    const auto fail = [](const QString &why) { return QVariantMap{ { "ok", false }, { "error", why } }; };
    const bool looksSvg = fileName.endsWith(QLatin1String(".svg"), Qt::CaseInsensitive) || data.left(512).contains("<svg");
    const qint64 limit = kind == QLatin1String("icon") ? kMaxIcon : kind == QLatin1String("loader") ? kMaxLoader : kMaxImage;
    if (data.size() > limit)
        return fail(tr("That file is too big."));

    if (looksSvg) {
        QString error;
        const QByteArray clean = cleanSvg(data, &error);
        return clean.isEmpty() ? fail(error) : store(clean, QStringLiteral("svg"));
    }
    if (kind == QLatin1String("icon"))
        return fail(tr("Icons need to be SVG drawings."));

    QBuffer buffer;
    buffer.setData(data);
    buffer.open(QIODevice::ReadOnly);
    QImageReader reader(&buffer);
    const QByteArray format = reader.format();
    if (!QList<QByteArray>{ "png", "jpeg", "jpg", "webp", "gif", "bmp" }.contains(format))
        return fail(tr("That isn't a picture f1int can use (PNG, JPG, WEBP, GIF or SVG)."));
    const QSize size = reader.size();
    if (!size.isValid() || size.width() > 12000 || size.height() > 12000)
        return fail(tr("That picture is too large."));
    // A loading animation keeps its frames (only after the reader confirmed they're real).
    if (kind == QLatin1String("loader") && reader.supportsAnimation() && reader.imageCount() > 1 && (format == "gif" || format == "webp"))
        return store(data, QString::fromLatin1(format));

    QImage image = reader.read();
    if (image.isNull())
        return fail(tr("That picture couldn't be read."));
    if (std::max(image.width(), image.height()) > kMaxSide)
        image = image.scaled(kMaxSide, kMaxSide, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    // Saved again from the pixels: no metadata, nothing but the picture.
    QByteArray out;
    QBuffer outBuffer(&out);
    outBuffer.open(QIODevice::WriteOnly);
    const bool alpha = image.hasAlphaChannel();
    image.save(&outBuffer, alpha ? "PNG" : "JPG", alpha ? -1 : 92);
    return store(out, alpha ? QStringLiteral("png") : QStringLiteral("jpg"));
}

QVariantMap Assets::addIcons(const QList<QUrl> &files)
{
    const QStringList known = iconNames();
    QVariantMap icons;
    QStringList skipped;
    for (const QUrl &u : files) {
        const QString name = QFileInfo(u.toLocalFile()).completeBaseName().toLower();
        if (!known.contains(name)) {
            skipped << QFileInfo(u.toLocalFile()).fileName();
            continue;
        }
        const QVariantMap r = add(u, QStringLiteral("icon"));
        if (r["ok"].toBool())
            icons.insert(name, r["id"]);
        else
            skipped << QFileInfo(u.toLocalFile()).fileName();
    }
    return { { "icons", icons }, { "added", icons.size() }, { "skipped", skipped } };
}

// ---------------------------------------------------------------- SVG cleaning

QByteArray Assets::cleanSvg(const QByteArray &svg, QString *error)
{
    // Drawing elements only. Everything else (script, foreignObject, iframe, animation,
    // anything unknown) is dropped together with its contents.
    static const QStringList elements = {
        "svg", "g", "defs", "symbol", "use", "title", "desc", "path", "rect", "circle", "ellipse", "line", "polyline",
        "polygon", "text", "tspan", "linearGradient", "radialGradient", "stop", "clipPath", "mask", "pattern", "style", "image" };
    QXmlStreamReader in(svg);
    QByteArray out;
    QXmlStreamWriter w(&out);
    int skipDepth = 0;
    bool sawSvg = false;
    while (!in.atEnd()) {
        in.readNext();
        if (in.isStartElement()) {
            if (skipDepth > 0 || !elements.contains(in.name().toString())) {
                ++skipDepth;
                continue;
            }
            sawSvg = sawSvg || in.name() == QLatin1String("svg");
            w.writeStartElement(in.namespaceUri().toString(), in.name().toString());
            if (in.name() == QLatin1String("svg"))
                w.writeDefaultNamespace(QStringLiteral("http://www.w3.org/2000/svg"));
            for (const QXmlStreamAttribute &a : in.attributes()) {
                const QString name = a.name().toString().toLower();
                const QString value = a.value().toString();
                const QString v = value.trimmed().toLower();
                if (name.startsWith(QLatin1String("on")))   // onload, onclick ...: scripts
                    continue;
                if (name == QLatin1String("href")) {
                    // Only links inside the drawing ("#id") or embedded PNG/JPEG pictures.
                    if (!v.startsWith(QLatin1Char('#')) && !v.startsWith(QLatin1String("data:image/png")) && !v.startsWith(QLatin1String("data:image/jpeg")))
                        continue;
                }
                if ((name == QLatin1String("style") || v.contains(QLatin1String("url("))) && v.contains(QRegularExpression(QStringLiteral("url\\(\\s*['\"]?\\s*[^#'\"\\s]"))))
                    continue;   // url(...) pointing outside the drawing
                if (v.contains(QLatin1String("javascript:")) || v.contains(QLatin1String("expression(")))
                    continue;
                w.writeAttribute(a.namespaceUri().toString(), a.name().toString(), value);
            }
        } else if (in.isEndElement()) {
            if (skipDepth > 0) { --skipDepth; continue; }
            w.writeEndElement();
        } else if (in.isCharacters() && skipDepth == 0 && !in.isWhitespace()) {
            QString text = in.text().toString();
            if (text.contains(QLatin1String("@import")) || text.contains(QRegularExpression(QStringLiteral("url\\(\\s*['\"]?\\s*[^#'\"\\s]"))))
                continue;   // CSS that loads things from elsewhere
            w.writeCharacters(text);
        }
    }
    if (in.hasError() || !sawSvg) {
        if (error)
            *error = QObject::tr("That isn't a valid SVG drawing.");
        return {};
    }
    QSvgRenderer check(out);
    if (!check.isValid()) {
        if (error)
            *error = QObject::tr("That SVG couldn't be drawn.");
        return {};
    }
    return out;
}

// ---------------------------------------------------------------- icons

QImage IconProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QString name = id.section(QLatin1Char('?'), 0, 0);
    const QString query = id.section(QLatin1Char('?'), 1);
    QByteArray svg;
    if (name.startsWith(QLatin1String("asset/"))) {   // from an icon pack (cleaned when it was added)
        QFile f(m_assets->path(name.mid(6)));
        if (f.open(QIODevice::ReadOnly))
            svg = f.readAll();
    } else {
        static const QRegularExpression ok(QStringLiteral("^[a-z0-9-]+$"));
        QFile f(QStringLiteral(":/icons/") + name + QStringLiteral(".svg"));
        if (ok.match(name).hasMatch() && f.open(QIODevice::ReadOnly))
            svg = f.readAll();
        // Icon weight: f1int's icons are line drawings, so a different stroke width is all it takes.
        const double weight = QUrlQuery_value(query, QStringLiteral("w")).toDouble();
        if (weight >= 0.5 && weight <= 3.5)
            svg.replace("stroke-width=\"1.75\"", "stroke-width=\"" + QByteArray::number(weight) + "\"");
    }
    const QSize out = requestedSize.isValid() && !requestedSize.isEmpty() ? requestedSize : QSize(24, 24);
    QImage image(out, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    QSvgRenderer renderer(svg);
    if (renderer.isValid()) {
        QPainter p(&image);
        renderer.render(&p);
    }
    if (size)
        *size = out;
    return image;
}
