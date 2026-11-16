import QtQuick
import QtQuick.Controls.Basic
import f1int

// One tab in the vertical tab bar: icon, title, sound and close buttons.
// Click to switch, middle-click to close, right-click for the menu, drag to reorder.
Item {
    id: row
    required property int tabId
    required property string title
    required property url icon
    required property bool loading
    required property bool asleep
    required property bool audible
    required property bool muted
    required property int groupId
    property var group: null        // { name, color, collapsed } when the tab is in a group
    property bool narrow: false     // tab bar collapsed to icons only
    signal menuRequested()
    signal muteToggled()

    readonly property bool current: tabId === Browser.tabs.currentId
    width: ListView.view ? ListView.view.width : 0
    height: group && group.collapsed ? 0 : 34
    visible: height > 0
    Behavior on height { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

    // Another tab dragged over this one takes its place.
    DropArea {
        anchors.fill: parent
        onEntered: (drag) => Browser.tabs.move(drag.source.tabId, row.tabId)
    }

    Rectangle {
        id: body
        property int tabId: row.tabId   // read by the DropArea of the tab it's dropped on
        width: row.width
        height: 34
        radius: 8
        color: row.current ? Theme.selected : hover.hovered ? Theme.hover : "transparent"
        opacity: row.asleep && !row.current ? 0.45 : 1   // sleeping tabs are dimmed
        Behavior on color { ColorAnimation { duration: Theme.anim } }

        Drag.active: mouse.drag.active
        Drag.source: body
        Drag.hotSpot.y: height / 2
        HoverHandler { id: hover }

        MouseArea {
            id: mouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            drag.target: body
            drag.axis: Drag.YAxis
            drag.threshold: 6
            onPressed: (m) => { if (m.button === Qt.LeftButton) Browser.tabs.currentId = row.tabId }
            onClicked: (m) => {
                if (m.button === Qt.MiddleButton) Browser.tabs.close(row.tabId)
                else if (m.button === Qt.RightButton) row.menuRequested()
            }
        }

        // In a group: a thin line in the group's colour.
        Rectangle {
            visible: row.group !== null
            x: 0
            width: 2
            height: parent.height - 14
            anchors.verticalCenter: parent.verticalCenter
            radius: 1
            color: row.group ? row.group.color : "transparent"
        }
        // The open tab: a small red dot.
        Rectangle {
            visible: row.current
            x: 5
            width: 4
            height: 4
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accent
        }

        Item {
            id: iconBox
            x: 12
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            Image {
                id: favicon
                anchors.fill: parent
                source: row.icon
                sourceSize: Qt.size(16, 16)   // decode small: saves RAM
                visible: !row.loading && status === Image.Ready
            }
            Icon {
                anchors.fill: parent
                glyph: "globe"
                color: Theme.dim
                visible: !row.loading && !favicon.visible
            }
            DotLoader {
                anchors.centerIn: parent
                visible: row.loading
            }
        }

        Text {
            anchors.left: iconBox.right
            anchors.leftMargin: 10
            anchors.right: buttons.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            visible: !row.narrow
            text: row.title || qsTr("New tab")
            color: row.current ? Theme.fg : Qt.darker(Theme.fg, Theme.dark ? 1.35 : 0.6)
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Row {
            id: buttons
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            visible: !row.narrow
            IconButton {
                visible: row.audible || row.muted
                implicitWidth: 24
                implicitHeight: 24
                iconSize: 14
                iconName: row.muted ? "muted" : "speaker"
                iconColor: row.muted ? Theme.dim : Theme.fg
                tip: row.muted ? qsTr("Unmute tab") : qsTr("Mute tab")
                onClicked: row.muteToggled()
            }
            IconButton {
                visible: hover.hovered || row.current
                implicitWidth: 24
                implicitHeight: 24
                iconSize: 14
                iconName: "close"
                tip: qsTr("Close tab (Ctrl+W)")
                onClicked: Browser.tabs.close(row.tabId)
            }
        }
    }

    // While dragging, lift the tab out of the list so it can float above the others.
    states: State {
        when: mouse.drag.active
        ParentChange { target: body; parent: row.ListView.view }
        PropertyChanges { target: body; z: 10; opacity: 0.9 }
    }
}
