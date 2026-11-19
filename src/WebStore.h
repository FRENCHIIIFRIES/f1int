#pragma once

#include <QByteArray>
#include <QRegularExpression>
#include <QUrl>

// Chrome Web Store helpers (header-only, so tests can use them without the whole browser).
namespace WebStore {

inline QString webStoreId(const QUrl &url)
{
    // chromewebstore.google.com/detail/<name>/<id>  (and the old chrome.google.com/webstore/detail/...)
    static const QRegularExpression id(QStringLiteral("/detail/(?:[^/]+/)?([a-p]{32})(?:[/?#]|$)"));
    const bool store = url.host() == QLatin1String("chromewebstore.google.com")
                       || (url.host() == QLatin1String("chrome.google.com") && url.path().startsWith(QLatin1String("/webstore")));
    return store ? id.match(url.path()).captured(1) : QString();
}

inline QByteArray zipFromCrx(const QByteArray &crx)
{
    // "Cr24", version, then (v3) a header of `n` bytes, or (v2) a key and a signature; the zip follows.
    if (crx.size() < 16 || !crx.startsWith("Cr24"))
        return {};
    const auto u32 = [&](int at) { return quint32(uchar(crx[at])) | quint32(uchar(crx[at + 1])) << 8 | quint32(uchar(crx[at + 2])) << 16 | quint32(uchar(crx[at + 3])) << 24; };
    const quint32 version = u32(4);
    qint64 start = version == 3 ? 12 + qint64(u32(8)) : version == 2 ? 16 + qint64(u32(8)) + qint64(u32(12)) : -1;
    if (start < 0 || start >= crx.size() || crx.mid(start, 4) != QByteArray("PK\x03\x04", 4))
        return {};
    return crx.mid(start);
}

} // namespace WebStore
