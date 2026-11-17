import QtQuick
import QtQuick.Controls.Basic
import f1int

// A small square button showing one icon, with a tooltip.
Button {
    id: button
    property string iconName
    property string tip            // tooltip, also read out by screen readers
    property color iconColor: Theme.fg
    property int iconSize: 16

    implicitWidth: 30
    implicitHeight: 30
    focusPolicy: Qt.NoFocus        // clicking it shouldn't steal focus from the page
    opacity: enabled ? 1 : 0.35    // disabled buttons fade right back
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    Accessible.name: tip
    ToolTip.text: tip
    ToolTip.visible: hovered && tip !== ""
    ToolTip.delay: 600

    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            glyph: button.iconName
            sourceSize: Qt.size(button.iconSize, button.iconSize)
            color: button.iconColor
        }
    }
    background: Rectangle {
        radius: Math.max(4, Theme.radius - 2)
        color: button.down ? Theme.press : button.hovered ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.anim } }
    }
}
