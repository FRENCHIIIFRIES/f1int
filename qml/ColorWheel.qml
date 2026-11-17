import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import f1int

// Pick any colour: click or drag on the wheel (direction = hue, distance from the
// centre = saturation), set brightness with the slider, or type a hex code.
ColumnLayout {
    id: picker
    property color color: "#D71921"
    signal picked(color color)

    property real hue: color.hsvHue < 0 ? 0 : color.hsvHue
    property real sat: color.hsvSaturation
    property real val: color.hsvValue
    function update() { color = Qt.hsva(hue, sat, val, 1); hex.text = color.toString() }

    spacing: 12

    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 200
        implicitHeight: 200

        // The wheel: hues around the circle (a conical gradient), fading to white in the
        // middle (a radial gradient) = less saturation towards the centre.
        Canvas {
            id: wheel
            anchors.fill: parent
            onAvailableChanged: requestPaint()   // draw as soon as it can
            onWidthChanged: requestPaint()
            onPaint: {
                const c = getContext("2d")
                const r = width / 2
                c.reset()
                // Qt's conical gradient runs anticlockwise; picking measures clockwise, hence 1 - p.
                const hues = c.createConicalGradient(r, r, 0)
                for (let i = 0; i <= 12; ++i)
                    hues.addColorStop(i / 12, Qt.hsva((1 - i / 12) % 1, 1, 1, 1))
                c.fillStyle = hues
                c.beginPath(); c.arc(r, r, r, 0, 2 * Math.PI); c.fill()
                const white = c.createRadialGradient(r, r, 0, r, r, r)
                white.addColorStop(0, Qt.rgba(1, 1, 1, 1))
                white.addColorStop(1, Qt.rgba(1, 1, 1, 0))
                c.fillStyle = white
                c.beginPath(); c.arc(r, r, r, 0, 2 * Math.PI); c.fill()
            }
        }
        Rectangle {   // darkens the wheel to match the brightness slider
            anchors.fill: parent
            radius: width / 2
            color: "black"
            opacity: Math.min(0.75, 1 - picker.val)   // never fully black, so the colours stay visible
        }
        Rectangle {   // marker on the current colour
            readonly property real angle: picker.hue * 2 * Math.PI
            x: parent.width / 2 + Math.cos(angle) * picker.sat * parent.width / 2 - width / 2
            y: parent.height / 2 + Math.sin(angle) * picker.sat * parent.height / 2 - height / 2
            width: 16
            height: 16
            radius: 8
            color: picker.color
            border.width: 2
            border.color: "white"
        }
        MouseArea {
            anchors.fill: parent
            function pick(m) {
                const dx = m.x - width / 2, dy = m.y - height / 2
                picker.hue = (Math.atan2(dy, dx) / (2 * Math.PI) + 1) % 1
                picker.sat = Math.min(1, Math.sqrt(dx * dx + dy * dy) / (width / 2))
                if (picker.val < 0.2) picker.val = 1
                picker.update()
            }
            onPressed: (m) => pick(m)
            onPositionChanged: (m) => pick(m)
        }
    }

    // Brightness
    Slider {
        id: brightness
        Layout.fillWidth: true
        from: 0
        to: 1
        value: picker.val
        onMoved: { picker.val = value; picker.update() }
        background: Rectangle {
            x: brightness.leftPadding
            y: brightness.topPadding + brightness.availableHeight / 2 - height / 2
            width: brightness.availableWidth
            height: 6
            radius: 3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "black" }
                GradientStop { position: 1; color: Qt.hsva(picker.hue, picker.sat, 1, 1) }
            }
        }
        handle: Rectangle {
            x: brightness.leftPadding + brightness.visualPosition * (brightness.availableWidth - width)
            y: brightness.topPadding + brightness.availableHeight / 2 - height / 2
            width: 18
            height: 18
            radius: 9
            color: picker.color
            border.width: 2
            border.color: "white"
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Rectangle { width: 30; height: 30; radius: 15; color: picker.color; border.width: 1; border.color: Theme.line }
        Ui.Field {
            id: hex
            Layout.fillWidth: true
            text: picker.color.toString()
            font.family: "Consolas, Menlo, monospace"
            validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,6}/ }
            onEditingFinished: {
                const t = text.startsWith("#") ? text : "#" + text
                if (/^#[0-9a-fA-F]{6}$/.test(t)) { picker.color = t; picker.hue = picker.color.hsvHue < 0 ? 0 : picker.color.hsvHue
                    picker.sat = picker.color.hsvSaturation; picker.val = picker.color.hsvValue }
            }
        }
        Ui.Pill { text: qsTr("Use"); primary: true; onClicked: { hex.editingFinished(); picker.picked(picker.color) } }
    }
}
