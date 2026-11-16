import QtQuick
import QtQuick.Controls.Basic
import f1int

// A small square toolbar button showing one symbol, with a tooltip.
// Real icons come with the design pass in Stage 4.
Button {
    id: button
    property string tip            // tooltip, also read out by screen readers

    implicitWidth: 30
    implicitHeight: 28
    font.pixelSize: 15
    // Windows' black-and-white symbol font; otherwise some symbols (⌂) become colour emoji.
    font.family: Qt.platform.os === "windows" ? "Segoe UI Symbol" : ""
    focusPolicy: Qt.NoFocus        // clicking it shouldn't steal focus from the page
    Accessible.name: tip
    ToolTip.text: tip
    ToolTip.visible: hovered && tip !== ""
    ToolTip.delay: 600

    contentItem: Text {
        text: button.text
        font: button.font
        color: button.enabled ? Theme.fg : Theme.dim
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 6
        color: button.down ? Theme.press : button.hovered ? Theme.hover : "transparent"
    }
}
