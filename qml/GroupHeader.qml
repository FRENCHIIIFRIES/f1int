import QtQuick
import f1int

// The title row above a tab group: colour dot, name, tab count.
// Click to fold the group away, right-click for its menu.
Item {
    id: header
    required property string section   // the group id as text; "" = tabs without a group
    property TabModel tabs
    property var group: null
    property bool narrow: false
    signal menuRequested()

    width: ListView.view ? ListView.view.width : 0
    height: group ? 32 : 0
    // ListView sets "visible" on section headers itself, so hide empty ones with opacity.
    opacity: group ? 1 : 0
    enabled: group !== null

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: hover.hovered ? Theme.hover : "transparent"
        HoverHandler { id: hover }

        Rectangle {
            id: dot
            x: 12
            width: 12
            height: 12
            radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: header.group ? header.group.color : "transparent"
        }
        Text {
            id: name
            anchors.left: dot.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: !header.narrow
            text: header.group ? header.group.name : ""
            color: Theme.fg
            font.pixelSize: Theme.px(13)
            font.weight: Font.Black
        }
        Text {
            anchors.left: name.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: !header.narrow
            text: header.group ? header.group.count : ""
            color: Theme.dim
            font.family: Theme.numberFont
            font.pixelSize: Theme.px(14)
            font.weight: Font.Bold
        }
        Icon {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: !header.narrow
            glyph: "chevron"
            sourceSize: Qt.size(12, 12)
            color: Theme.dim
            rotation: header.group && header.group.collapsed ? 0 : 90
            Behavior on rotation { NumberAnimation { duration: Theme.anim } }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => {
                if (m.button === Qt.RightButton) header.menuRequested()
                else header.tabs.editGroup(header.group.id, { collapsed: !header.group.collapsed })
            }
        }
    }
}
