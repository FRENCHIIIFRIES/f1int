import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import f1int

// The tab bar (left or right, see Settings > Appearance): toolbar (optional), search,
// new tab, pinned tabs, the other tabs with their groups, and a small footer.
// Collapses to icons; hovering opens it again. Drag its inner edge to resize.
Rectangle {
    id: sidebar
    property TabModel tabs

    property bool collapsed: String(Browser.setting("tabbar/collapsed", false)) === "true"
    property real expandedWidth: Number(Browser.setting("tabbar/width", 260))
    readonly property int narrowWidth: 56
    readonly property bool narrow: collapsed && !hover.hovered
    // Room the page leaves for the bar. When collapsed, the bar floats over the page on hover.
    readonly property real reservedWidth: collapsed ? narrowWidth : expandedWidth
    // Where the toolbar sits when it's in the tab bar (Main.qml moves it here).
    property alias toolbarSlot: slot
    property bool hasToolbar: false
    property bool searchOpen: false   // the tab search box (footer button or Ctrl+Shift+A)

    signal newTabRequested()
    signal tabMenuRequested(int tabId)
    signal groupMenuRequested(int groupId)
    signal muteToggled(int tabId)
    signal panelRequested(string name)

    function toggle() {
        collapsed = !collapsed
        Browser.setSetting("tabbar/collapsed", collapsed)
    }
    function focusSearch() {
        if (collapsed) toggle()
        searchOpen = true
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
    // Normally see-through (the window's tint shows); solid while floating over the page.
    color: collapsed && !narrow ? Theme.chromeSolid : "transparent"
    clip: true
    HoverHandler { id: hover }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.inset
        anchors.leftMargin: Theme.tabsOnRight ? 0 : Theme.inset
        anchors.rightMargin: Theme.tabsOnRight ? Theme.inset : 0
        spacing: Theme.gap

        Item {
            id: slot
            visible: sidebar.hasToolbar && !sidebar.collapsed
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 82 : 0
        }

        // ---- Search open tabs (opened from the footer) ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: (sidebar.searchOpen || search.text !== "") && !sidebar.narrow
            TextField {
                id: search
                visible: !sidebar.narrow
                Layout.fillWidth: true
                implicitHeight: Theme.rowHeight
                leftPadding: 32
                placeholderText: Theme.showTabCount ? (sidebar.tabs.count === 1 ? qsTr("Search 1 tab") : qsTr("Search %1 tabs").arg(sidebar.tabs.count)) : qsTr("Search tabs")
                placeholderTextColor: Theme.dim
                color: Theme.fg
                font.pixelSize: Theme.px(13)
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.textOnAccent
                Accessible.name: qsTr("Search open tabs")
                background: Rectangle {
                    radius: Theme.radius
                    color: Theme.field
                    border.width: search.activeFocus ? 1 : 0
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
                }
                Icon {
                    x: 11
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "search"
                    sourceSize: Qt.size(14, 14)
                    color: Theme.dim
                }
                Keys.onEscapePressed: { text = ""; focus = false; sidebar.searchOpen = false }
            }
            Text {   // collapsed: just the number of tabs
                visible: sidebar.narrow && Theme.showTabCount
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: sidebar.tabs.count
                color: Theme.dim
                font.family: Theme.numberFont
                font.pixelSize: Theme.px(13)
            }
        }

        // ---- New tab ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.rowHeight
            radius: Theme.radius
            color: newTabHover.hovered ? Theme.hover : "transparent"
            HoverHandler { id: newTabHover; cursorShape: Qt.PointingHandCursor }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("New tab")
            Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; glyph: "plus"; color: Theme.dim }
            Text {
                x: 38
                anchors.verticalCenter: parent.verticalCenter
                visible: !sidebar.narrow
                text: qsTr("New tab")
                color: Theme.dim
                font.pixelSize: Theme.px(13)
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: !sidebar.narrow && newTabHover.hovered
                text: "Ctrl+T"
                color: Theme.dim
                font.pixelSize: Theme.px(11)
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
            cellHeight: Theme.rowHeight + 10
            model: TabFilter { sourceModel: sidebar.tabs; pinned: true; text: search.text }
            delegate: PinnedTile { tabs: sidebar.tabs; onMenuRequested: sidebar.tabMenuRequested(tabId) }
            moveDisplaced: Transition { NumberAnimation { properties: "x,y"; duration: Theme.anim } }
        }
        Rectangle {
            visible: pinned.count > 0
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
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
                text: qsTr("No tabs match \"%1\"").arg(search.text)
                color: Theme.dim
                font.pixelSize: Theme.px(12)
            }
        }

        // ---- Footer: quick buttons and (optionally) f1int's RAM use ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: !sidebar.narrow
            IconButton { iconName: "key"; iconColor: Theme.dim; tip: qsTr("Passwords"); onClicked: sidebar.panelRequested("passwords") }
            IconButton { iconName: "history"; iconColor: Theme.dim; tip: qsTr("History (Ctrl+H)"); onClicked: sidebar.panelRequested("history") }
            IconButton { iconName: "settings"; iconColor: Theme.dim; tip: qsTr("Settings (Ctrl+,)"); onClicked: sidebar.panelRequested("settings") }
            IconButton { iconName: "search"; iconColor: sidebar.searchOpen ? Theme.fg : Theme.dim; tip: qsTr("Search tabs (Ctrl+Shift+A)"); onClicked: sidebar.searchOpen ? (sidebar.searchOpen = false, search.text = "") : sidebar.focusSearch() }
            Item { Layout.fillWidth: true }
            Text {
                id: ram
                visible: Theme.showRam && mb > 0
                property int mb: 0
                text: mb + " MB"
                color: Theme.dim
                font.family: Theme.numberFont
                font.pixelSize: Theme.px(12)
                Layout.rightMargin: 6
                function refresh() { mb = Math.round(Browser.memoryInfo().total / 1048576) }
                Component.onCompleted: refresh()
                Timer { interval: 10000; repeat: true; running: Theme.showRam && Qt.application.state === Qt.ApplicationActive; onTriggered: ram.refresh() }
                HoverHandler { id: ramHover }
                ToolTip.visible: ramHover.hovered
                ToolTip.text: qsTr("Memory used by f1int (open Memory from the menu for details)")
            }
            IconButton {
                iconName: "sidebar"
                iconColor: sidebar.collapsed ? Theme.accent : Theme.dim
                tip: sidebar.collapsed ? qsTr("Keep tab bar open (Ctrl+Shift+S)") : qsTr("Collapse tab bar (Ctrl+Shift+S)")
                onClicked: sidebar.toggle()
            }
        }
    }

    // Drag the inner edge to resize; the width is remembered.
    MouseArea {
        id: resizer
        visible: !sidebar.collapsed
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: Theme.tabsOnRight ? 0 : parent.width - width
        width: 6
        cursorShape: Qt.SizeHorCursor
        onPositionChanged: (m) => {
            if (!pressed) return
            const p = mapToItem(sidebar, m.x, 0).x
            sidebar.expandedWidth = Math.max(200, Math.min(440, Theme.tabsOnRight ? sidebar.width - p : p))
        }
        onReleased: Browser.setSetting("tabbar/width", Math.round(sidebar.expandedWidth))
    }
}
