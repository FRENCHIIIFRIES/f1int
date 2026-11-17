import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import f1int

// The vertical tab bar on the left: tab count, search, new tab, pinned tabs,
// then the other tabs with their groups. Collapses to icons; hovering opens it again.
Rectangle {
    id: sidebar
    property TabModel tabs

    property bool collapsed: String(Browser.setting("tabbar/collapsed", false)) === "true"
    property real expandedWidth: Number(Browser.setting("tabbar/width", 248))
    readonly property int narrowWidth: 56
    readonly property bool narrow: collapsed && !hover.hovered
    // Room the page leaves for the bar. When collapsed, the bar floats over the page on hover.
    readonly property real reservedWidth: collapsed ? narrowWidth : expandedWidth

    signal newTabRequested()
    signal tabMenuRequested(int tabId)
    signal groupMenuRequested(int groupId)
    signal muteToggled(int tabId)

    function toggle() {
        collapsed = !collapsed
        Browser.setSetting("tabbar/collapsed", collapsed)
    }
    function focusSearch() {
        if (collapsed) toggle()
        search.forceActiveFocus()
    }
    // Group details for a group id, or null. Re-runs whenever the groups change.
    function groupInfo(id) {
        const groups = sidebar.tabs.groups
        for (let i = 0; i < groups.length; ++i)
            if (groups[i].id === id)
                return groups[i]
        return null
    }

    width: narrow ? narrowWidth : expandedWidth
    Behavior on width {
        enabled: !resizer.pressed
        NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
    }
    color: Theme.bg
    clip: true
    HoverHandler { id: hover }

    Rectangle {   // 1px divider on the right
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Theme.line
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        anchors.rightMargin: 9
        spacing: 6

        // ---- Header: tab count in dot-matrix digits ----
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: 6
            Text {
                Layout.leftMargin: 6
                text: (sidebar.tabs.count < 10 ? "0" : "") + sidebar.tabs.count
                color: Theme.fg
                font.family: Theme.dotFont
                font.pixelSize: 26
                font.weight: Font.Black
            }
            Text {
                visible: !sidebar.narrow
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 8
                text: qsTr("TABS")
                color: Theme.dim
                font.pixelSize: 10
                font.letterSpacing: 2
            }
            Item { Layout.fillWidth: true }
            IconButton {
                visible: !sidebar.narrow
                iconName: "sidebar"
                iconColor: sidebar.collapsed ? Theme.accent : Theme.fg
                tip: sidebar.collapsed ? qsTr("Keep tab bar open (Ctrl+Shift+S)") : qsTr("Collapse tab bar (Ctrl+Shift+S)")
                onClicked: sidebar.toggle()
            }
        }

        // ---- Search open tabs ----
        TextField {
            id: search
            visible: !sidebar.narrow
            Layout.fillWidth: true
            implicitHeight: 30
            leftPadding: 30
            placeholderText: qsTr("Search tabs")
            placeholderTextColor: Theme.dim
            color: Theme.fg
            font.pixelSize: 12
            selectByMouse: true
            selectionColor: Theme.accent
            Accessible.name: qsTr("Search open tabs")
            background: Rectangle {
                radius: 8
                color: Theme.surface
                border.width: 1
                border.color: search.activeFocus ? Theme.dim : Theme.line
            }
            Icon {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                glyph: "search"
                sourceSize: Qt.size(13, 13)
                color: Theme.dim
            }
            Keys.onEscapePressed: { text = ""; focus = false }
        }

        // ---- New tab ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 8
            color: newTabHover.hovered ? Theme.hover : "transparent"
            HoverHandler { id: newTabHover }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("New tab")
            Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; glyph: "plus" }
            Text {
                x: 38
                anchors.verticalCenter: parent.verticalCenter
                visible: !sidebar.narrow
                text: qsTr("New tab")
                color: Theme.fg
                font.pixelSize: 13
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: !sidebar.narrow && newTabHover.hovered
                text: "Ctrl T"
                color: Theme.dim
                font.pixelSize: 11
            }
            MouseArea { anchors.fill: parent; onClicked: sidebar.newTabRequested() }
        }

        // ---- Pinned tabs: icon grid ----
        GridView {
            id: pinned
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            visible: count > 0
            interactive: false
            cellWidth: sidebar.narrow ? width : Math.floor(width / 4)
            cellHeight: 40
            model: TabFilter { sourceModel: sidebar.tabs; pinned: true; text: search.text }
            delegate: PinnedTile { tabs: sidebar.tabs; onMenuRequested: sidebar.tabMenuRequested(tabId) }
            moveDisplaced: Transition { NumberAnimation { properties: "x,y"; duration: Theme.anim } }
        }
        Rectangle {
            visible: pinned.count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.line
        }

        // ---- Tabs, with group headers ----
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: TabFilter { sourceModel: sidebar.tabs; pinned: false; text: search.text }
            section.property: "groupKey"
            section.delegate: GroupHeader {
                tabs: sidebar.tabs
                group: sidebar.groupInfo(Number(section))
                narrow: sidebar.narrow
                onMenuRequested: sidebar.groupMenuRequested(group.id)
            }
            delegate: TabRow {
                tabs: sidebar.tabs
                group: sidebar.groupInfo(groupId)
                narrow: sidebar.narrow
                onMenuRequested: sidebar.tabMenuRequested(tabId)
                onMuteToggled: sidebar.muteToggled(tabId)
            }
            moveDisplaced: Transition { NumberAnimation { properties: "y"; duration: Theme.anim } }
            displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.anim } }
            ScrollBar.vertical: ScrollBar { width: 4; policy: ScrollBar.AsNeeded }

            Text {   // nothing matches the search
                anchors.centerIn: parent
                visible: list.count === 0 && search.text !== ""
                text: qsTr("No tabs match")
                color: Theme.dim
                font.pixelSize: 12
            }
        }

        // ---- Footer: decorative dot grid ----
        DotGrid {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
        }
    }

    // Drag the right edge to resize; the width is remembered.
    MouseArea {
        id: resizer
        visible: !sidebar.collapsed
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 5
        cursorShape: Qt.SizeHorCursor
        onPositionChanged: (m) => {
            if (pressed)
                sidebar.expandedWidth = Math.max(180, Math.min(440, mapToItem(sidebar, m.x, 0).x))
        }
        onReleased: Browser.setSetting("tabbar/width", Math.round(sidebar.expandedWidth))
    }
}
