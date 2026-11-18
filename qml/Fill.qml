import QtQuick
import QtQuick.Effects
import f1int

// A surface's background (Theme.fill): a colour, a gradient at any angle, a picture
// (fitted, positioned, dimmed or blurred) or a pattern over the colour.
Item {
    id: fill
    property var spec: Theme.fillDefaults
    property color base: "black"   // the surface's own colour
    readonly property var colors: fill.spec.colors && fill.spec.colors.length >= 2 ? fill.spec.colors
                                  : fill.spec.colors && fill.spec.colors.length === 1 ? [fill.spec.colors[0], fill.base] : [fill.base, Qt.darker(fill.base, 1.6)]
    clip: true
    opacity: fill.spec.opacity

    Rectangle {
        anchors.fill: parent
        visible: fill.spec.type !== "gradient"
        color: fill.base
        Behavior on color { ColorAnimation { duration: Theme.anim * 2 } }   // switching looks fades
    }

    // Any angle: a big rotated square with a top-to-bottom gradient, cut to the surface.
    // (The angle works like CSS: 180 = top to bottom, 90 = left to right.)
    Rectangle {
        visible: fill.spec.type === "gradient"
        anchors.centerIn: parent
        width: Math.hypot(parent.width, parent.height)
        height: width
        rotation: fill.spec.angle - 180
        gradient: Gradient {
            GradientStop { position: 0; color: fill.colors[0] }
            GradientStop { position: fill.colors.length > 2 ? 0.5 : 1; color: fill.colors[1] }
            GradientStop { position: 1; color: fill.colors[fill.colors.length - 1] }
        }
    }

    Image {
        anchors.fill: parent
        visible: fill.spec.type === "image" && status === Image.Ready
        source: fill.spec.type === "image" ? Browser.assets.url(fill.spec.image) : ""
        asynchronous: true
        sourceSize: fill.spec.fit === "tile" ? undefined : Qt.size(2560, 2560)   // never decoded larger than this (RAM)
        fillMode: ({ fill: Image.PreserveAspectCrop, fit: Image.PreserveAspectFit, stretch: Image.Stretch,
                     tile: Image.Tile, center: Image.Pad })[fill.spec.fit] || Image.PreserveAspectCrop
        horizontalAlignment: fill.spec.position === "left" ? Image.AlignLeft : fill.spec.position === "right" ? Image.AlignRight : Image.AlignHCenter
        verticalAlignment: fill.spec.position === "top" ? Image.AlignTop : fill.spec.position === "bottom" ? Image.AlignBottom : Image.AlignVCenter
        layer.enabled: fill.spec.blur > 0
        layer.effect: MultiEffect { blurEnabled: true; blur: fill.spec.blur; blurMax: 64; autoPaddingEnabled: false }
    }
    Rectangle {   // dimming keeps text on top of a picture readable
        anchors.fill: parent
        visible: fill.spec.type === "image" && fill.spec.dim > 0
        color: "black"
        opacity: fill.spec.dim
    }

    PatternCanvas {
        anchors.fill: parent
        visible: fill.spec.type === "pattern"
        kind: fill.spec.pattern
        ink: fill.spec.patternColor !== "" ? fill.spec.patternColor : Theme.fg
        size: fill.spec.patternScale
        opacity: fill.spec.patternOpacity
    }
}
