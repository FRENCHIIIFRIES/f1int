// Tests for uploaded files (src/Assets.cpp): SVG cleaning and picture checks.
#include <QtTest>
#include <QBuffer>
#include <QImage>
#include <QTemporaryDir>
#include "Assets.h"

class TestAssets : public QObject
{
    Q_OBJECT
private slots:
    void svgKeepsTheDrawing()
    {
        const QByteArray in = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><path d='M1 1h20' stroke='#fff'/><use href='#a'/></svg>";
        const QByteArray out = Assets::cleanSvg(in);
        QVERIFY(out.contains("<path"));
        QVERIFY(out.contains("href=\"#a\""));
    }
    void svgLosesEverythingThatRunsOrFetches()
    {
        const QByteArray in = "<svg xmlns='http://www.w3.org/2000/svg' onload='alert(1)' viewBox='0 0 10 10'>"
"<script>alert(2)</script>"
"<foreignObject><iframe src='https://evil.test'></iframe></foreignObject>"
"<a href='javascript:alert(3)'><rect width='5' height='5'/></a>"
"<image href='https://evil.test/x.png' width='5' height='5'/>"
"<rect width='5' height='5' style='fill:url(https://evil.test/p)' onclick='alert(4)'/>"
"<style>@import url(https://evil.test/a.css); rect{fill:red}</style>"
"<circle r='3' fill='url(#g)'/>"
"</svg>";
        const QByteArray out = Assets::cleanSvg(in);
        QVERIFY(!out.isEmpty());
        for (const char *bad : { "onload", "script", "alert", "foreignObject", "iframe", "evil.test", "javascript", "@import", "onclick" })
            QVERIFY2(!out.contains(bad), bad);
        QVERIFY(out.contains("url(#g)"));   // links inside the drawing stay
    }
    void notAnSvg()
    {
        QString error;
        QVERIFY(Assets::cleanSvg("<html><body>hi</body></html>", &error).isEmpty());
        QVERIFY(!error.isEmpty());
        QVERIFY(Assets::cleanSvg("<svg", &error).isEmpty());
    }
    void picturesAreSavedAgain()
    {
        QTemporaryDir dir;
        Assets assets(dir.path());
        QImage img(64, 32, QImage::Format_RGB32);
        img.fill(Qt::red);
        QByteArray png;
        QBuffer b(&png);
        b.open(QIODevice::WriteOnly);
        img.save(&b, "PNG");
        const QVariantMap r = assets.addData(png + QByteArray("trailing junk after the picture"), "x.png", "image");
        QVERIFY2(r["ok"].toBool(), qPrintable(r["error"].toString()));
        QVERIFY(r["id"].toString().endsWith(".jpg"));   // no transparency: stored as JPEG, from the pixels
        QVERIFY(!assets.url(r["id"].toString()).isEmpty());
        QVERIFY(!assets.addData("not a picture", "x.png", "image")["ok"].toBool());
        QVERIFY(!assets.addData(png, "x.png", "icon")["ok"].toBool());   // icons must be SVG
        QVERIFY(assets.url("../../secrets.txt").isEmpty());              // only stored names resolve
    }
};

QTEST_MAIN(TestAssets)
#include "tst_assets.moc"
