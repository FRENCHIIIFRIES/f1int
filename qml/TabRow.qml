import QtQuick
import QtQuick.Controls.Basic
import f1int

// One tab in the tab bar: icon, title, sound and close buttons.
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
    property TabModel tabs
    property var group: null        // { name, color, collapsed } when the tab is in a group
    property bool narrow: false     // tab bar collapsed to icons only
    signal menuRequested()
    signal muteToggled()

    readonly property bool current: tabId === tabs.currentId
    width: ListView.view ? ListView.view.width : 0
    height: group && group.collapsed ? 0 : Theme.rowHeight
    visible: height > 0
    Behavior on height { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

    // Another tab dragged over this one takes its place.
    DropArea {
        anchors.fill: parent
        onEntered: (drag) => row.tabs.move(drag.source.tabId, row.tabId)
    }

    Rectangle {
        id: body
        property int tabId: row.tabId   // read by the DropArea of the tab it's dropped on
        width: row.width
        height: Theme.rowHeight
        radius: Theme.tabRadius
        // Open tab: raised fill + hairline (pill/square), or an accent bar (line style).
        readonly property bool filled: row.current && Theme.tabStyle !== "line"
        color: filled ? Theme.tab : hover.hovered && Theme.hoverEffects ? Theme.hover : "transparent"
        border.width: filled ? 1 : 0
        border.color: Theme.line
        opacity: row.asleep && !row.current ? 0.5 : 1   // sleeping tabs are faded
        Behavior on color { ColorAnimation { duration: Theme.anim } }

        Drag.active: mouse.drag.active
        Drag.source: body
        Drag.hotSpot.y: height / 2
        HoverHandler { id: hover }
        Accessible.role: Accessible.PageTab
        Accessible.name: row.title || qsTr("New tab")
        Accessible.selected: row.current

        MouseArea {
            id: mouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            drag.target: body
            drag.axis: Drag.YAxis
            drag.threshold: 6
            onPressed: (m) => { if (m.button === Qt.LeftButton) row.tabs.currentId = row.tabId }
            onClicked: (m) => {
                if (m.button === Qt.MiddleButton) row.tabs.close(row.tabId)
                else if (m.button === Qt.RightButton) row.menuRequested()
            }
        }

        Rectangle {   // line style: accent bar on the open tab
            visible: row.current && Theme.tabStyle === "line"
            width: 3
            height: parent.height * 0.6
            anchors.verticalCenter: parent.verticalCenter
            radius: 1.5
            color: Theme.accent
        }
        // In a group: a short bar in the group's colour.
        Rectangle {
            visible: row.group !== null && !(row.current && Theme.tabStyle === "line")
            x: 3
            width: 3
            height: parent.height * 0.45
            anchors.verticalCenter: parent.verticalCenter
            radius: 1.5
            color: row.group ? row.group.color : "transparent"
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
                visible: !row.loading && status === Image.Ready && implicitWidth > 0   // the favicon store can return an empty image
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
                color: Theme.dim
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
            color: row.current ? Theme.fg : Theme.dim
            font.pixelSize: Theme.px(13)
            font.weight: row.current ? Font.Medium : Font.Normal
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
                iconColor: row.muted ? Theme.dim : Theme.accent2
                tip: row.muted ? qsTr("Unmute tab") : qsTr("Mute tab")
                onClicked: row.muteToggled()
            }
            IconButton {
                visible: hover.hovered
                implicitWidth: 24
                implicitHeight: 24
                iconSize: 14
                iconName: "close"
                iconColor: Theme.dim
                tip: qsTr("Close tab (Ctrl+W)")
                onClicked: row.tabs.close(row.tabId)
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
