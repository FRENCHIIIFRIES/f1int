import QtQuick
import QtQuick.Controls.Basic
import f1int

// A pinned tab: just its icon, in the grid at the top of the tab bar.
Item {
    id: tile
    required property int tabId
    required property string title
    required property url icon
    required property bool loading
    required property bool asleep
    signal menuRequested()

    readonly property bool current: tabId === Browser.tabs.currentId
    width: GridView.view.cellWidth
    height: GridView.view.cellHeight

    DropArea {
        anchors.fill: parent
        onEntered: (drag) => Browser.tabs.move(drag.source.tabId, tile.tabId)
    }

    Rectangle {
        id: body
        property int tabId: tile.tabId
        x: 2
        y: 2
        width: tile.width - 4
        height: tile.height - 4
        radius: 8
        color: tile.current ? Theme.selected : hover.hovered ? Theme.hover : Theme.surface
        border.width: 1
        border.color: tile.current ? Theme.accent : Theme.line
        opacity: tile.asleep && !tile.current ? 0.45 : 1
        Drag.active: mouse.drag.active
        Drag.source: body
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        HoverHandler { id: hover }
        ToolTip.text: tile.title
        ToolTip.visible: hover.hovered && !mouse.drag.active
        ToolTip.delay: 600

        Image {
            id: favicon
            anchors.centerIn: parent
            width: 16
            height: 16
            source: tile.icon
            sourceSize: Qt.size(16, 16)
            visible: !tile.loading && status === Image.Ready
        }
        Icon {
            anchors.centerIn: parent
            glyph: "globe"
            color: Theme.dim
            visible: !tile.loading && !favicon.visible
        }
        DotLoader { anchors.centerIn: parent; visible: tile.loading }

        MouseArea {
            id: mouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            drag.target: body
            drag.threshold: 6
            onPressed: (m) => { if (m.button === Qt.LeftButton) Browser.tabs.currentId = tile.tabId }
            onClicked: (m) => {
                if (m.button === Qt.MiddleButton) Browser.tabs.close(tile.tabId)
                else if (m.button === Qt.RightButton) tile.menuRequested()
            }
        }
    }

    states: State {
        when: mouse.drag.active
        ParentChange { target: body; parent: tile.GridView.view }
        PropertyChanges { target: body; z: 10 }
    }
}
