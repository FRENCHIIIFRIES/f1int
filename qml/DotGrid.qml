import QtQuick
import f1int

// Decorative field of small dots (tab bar footer, empty states).
// Drawn once into a texture, only redrawn when its size or colour changes.
Canvas {
    property real spacing: 9
    property real dot: 1.5
    property color color: Theme.fg
    property real dotOpacity: 0.14

    renderStrategy: Canvas.Cooperative
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const c = getContext("2d")
        c.reset()
        c.fillStyle = color
        c.globalAlpha = dotOpacity
        for (let y = spacing / 2; y < height; y += spacing)
            for (let x = spacing / 2; x < width; x += spacing)
                c.fillRect(x, y, dot, dot)
    }
}
