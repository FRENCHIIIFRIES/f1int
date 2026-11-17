import QtQuick
import QtQuick.Controls.Basic
import f1int

// A right-click / "more" menu in f1int's style: dark panel, thin border, rounded.
Menu {
    id: menu
    padding: 6

    background: Rectangle {
        implicitWidth: 230
        color: Theme.surface
        border.width: 1
        border.color: Theme.line
        radius: Theme.cardRadius
    }

    delegate: MenuItem {
        id: item
        implicitHeight: Theme.rowHeight
        indicator: Item {}
        arrow: Icon {
            visible: item.subMenu !== null
            glyph: "chevron"
            sourceSize: Qt.size(12, 12)
            color: Theme.dim
            x: item.width - width - 10
            y: (item.height - height) / 2
        }
        contentItem: Text {
            leftPadding: 8
            text: item.text
            color: item.enabled ? Theme.fg : Theme.dim
            font.pixelSize: Theme.px(13)
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 6
            color: item.highlighted ? Theme.hover : "transparent"
        }
    }
}
