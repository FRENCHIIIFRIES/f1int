import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import f1int

// A right-click / "more" menu in f1int's style: raised panel, soft shadow, roomy rows.
Menu {
    id: menu
    padding: 6
    topPadding: 6
    bottomPadding: 6

    enter: Transition {   // a quick fade and grow from where it opens
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.anim * 0.7 }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.anim * 0.7; easing.type: Easing.OutCubic }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.anim * 0.4 } }

    background: Rectangle {
        implicitWidth: 248
        color: Theme.surface
        border.width: 1
        border.color: Theme.line
        radius: Theme.cardRadius
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.35); shadowBlur: 0.6; shadowVerticalOffset: 4 }
    }

    delegate: MenuItem {
        id: item
        implicitHeight: Math.max(36, Theme.rowHeight + 2)
        indicator: Item {}
        arrow: Icon {
            visible: item.subMenu !== null
            glyph: "chevron"
            sourceSize: Qt.size(12, 12)
            color: Theme.dim
            x: item.width - width - 12
            y: (item.height - height) / 2
        }
        contentItem: Text {
            leftPadding: 10
            rightPadding: 22
            text: item.text
            color: item.enabled ? Theme.fg : Theme.dim
            opacity: item.enabled ? 1 : 0.6
            font.pixelSize: Theme.px(14)
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Math.max(4, Theme.radius - 2)
            color: item.down ? Theme.press : item.highlighted ? Theme.hover : "transparent"
        }
    }
}
