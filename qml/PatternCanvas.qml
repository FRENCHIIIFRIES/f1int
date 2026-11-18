import QtQuick
import f1int

// Geometric patterns for backgrounds: dots, grid, lines, diagonal, waves, cross.
// Drawn once into a texture; redrawn only when the size or the settings change.
Canvas {
    id: canvas
    property string kind: "dots"
    property color ink: Theme.fg
    property real size: 1            // 0.5 = fine ... 3 = large
    renderStrategy: Canvas.Cooperative
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onKindChanged: requestPaint()
    onInkChanged: requestPaint()
    onSizeChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    onPaint: {
        const c = getContext("2d")
        c.reset()
        if (!visible) return
        const step = 14 * size
        c.fillStyle = ink
        c.strokeStyle = ink
        c.lineWidth = Math.max(1, size)
        c.beginPath()
        if (kind === "dots") {
            for (let y = step / 2; y < height; y += step)
                for (let x = step / 2; x < width; x += step)
                    c.rect(x, y, 1.6 * size, 1.6 * size)
            c.fill()
            return
        }
        if (kind === "grid" || kind === "lines")
            for (let y = step; y < height; y += step) { c.moveTo(0, y); c.lineTo(width, y) }
        if (kind === "grid")
            for (let x = step; x < width; x += step) { c.moveTo(x, 0); c.lineTo(x, height) }
        if (kind === "diagonal")
            for (let x = -height; x < width; x += step) { c.moveTo(x, height); c.lineTo(x + height, 0) }
        if (kind === "waves")
            for (let y = step; y < height + step; y += step * 1.4) {
                c.moveTo(0, y)
                for (let x = 0; x <= width; x += 6) c.lineTo(x, y + Math.sin(x / (step * 0.8)) * step * 0.3)
            }
        if (kind === "cross")
            for (let y = step / 2; y < height; y += step * 2)
                for (let x = step / 2; x < width; x += step * 2) {
                    c.moveTo(x - 3 * size, y); c.lineTo(x + 3 * size, y)
                    c.moveTo(x, y - 3 * size); c.lineTo(x, y + 3 * size)
                }
        c.stroke()
    }
}
