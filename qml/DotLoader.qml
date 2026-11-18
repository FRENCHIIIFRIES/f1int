import QtQuick
import f1int

// Loading indicator, in the style chosen in Appearance: dots that light up in turn
// (f1int's own), a spinner, a pulse, a sliding bar, or your own (animated) picture.
// Stands still when the system turns animations off.
Item {
    id: loader
    property color color: Theme.accent
    property int dot: 3
    readonly property string style: Theme.loaderStyle === "image" && Theme.loaderImage === "" ? "dots" : Theme.loaderStyle
    readonly property bool moving: visible && !Browser.reduceMotion
    implicitWidth: style === "dots" ? dot * 3 + 4 : style === "bar" ? 18 : 14
    implicitHeight: style === "dots" ? dot : style === "bar" ? 3 : 14

    Row {
        visible: loader.style === "dots"
        spacing: 2
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: loader.dot
                height: loader.dot
                radius: loader.dot / 2
                color: loader.color
                opacity: Browser.reduceMotion ? 0.6 : 0.2
                // Each dot waits its turn; every loop is 750 ms so they stay in step.
                SequentialAnimation on opacity {
                    running: loader.moving && loader.style === "dots"
                    loops: Animation.Infinite
                    PauseAnimation { duration: index * 150 }
                    NumberAnimation { to: 1; duration: 150 }
                    NumberAnimation { to: 0.2; duration: 300 }
                    PauseAnimation { duration: (2 - index) * 150 }
                }
            }
        }
    }
    Rectangle {   // spinner: a ring with a gap, turning
        visible: loader.style === "spinner"
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Qt.rgba(loader.color.r, loader.color.g, loader.color.b, 0.25)
        Rectangle { width: 4; height: 4; radius: 2; color: loader.color; x: parent.width / 2 - 2; y: -1 }
        RotationAnimation on rotation { running: loader.moving && loader.style === "spinner"; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
    }
    Rectangle {   // pulse: a dot breathing
        visible: loader.style === "pulse"
        anchors.centerIn: parent
        width: 8; height: 8; radius: 4
        color: loader.color
        SequentialAnimation on scale {
            running: loader.moving && loader.style === "pulse"
            loops: Animation.Infinite
            NumberAnimation { to: 1.6; duration: 450; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.8; duration: 450; easing.type: Easing.InOutSine }
        }
    }
    Item {   // bar: a short segment sliding along a track
        visible: loader.style === "bar"
        anchors.fill: parent
        clip: true
        Rectangle { anchors.fill: parent; radius: 1.5; color: Qt.rgba(loader.color.r, loader.color.g, loader.color.b, 0.25) }
        Rectangle {
            width: 7; height: parent.height; radius: 1.5; color: loader.color
            NumberAnimation on x { running: loader.moving && loader.style === "bar"; from: -7; to: 18; duration: 800; loops: Animation.Infinite }
        }
    }
    AnimatedImage {   // your own: a GIF or animated WEBP (or a still picture)
        visible: loader.style === "image"
        anchors.fill: parent
        source: loader.style === "image" ? Browser.assets.url(Theme.loaderImage) : ""
        playing: loader.moving
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(32, 32)
    }
}
