import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import f1int

// The tab column (left or right): f1int's deepest surface. From the top: the logo row
// (lined up with the toolbar), the toolbar when it lives here, tab search, pinned sites,
// "New tab", the tabs with their groups, what's playing, and your shortcuts.
// Collapses to icons (Ctrl+Shift+S); resting the mouse on it slides it open over the page.
Rectangle {
    id: sidebar
    property TabModel tabs

    property bool collapsed: String(Browser.setting("tabbar/collapsed", false)) === "true"
    property real expandedWidth: Number(Browser.setting("tabbar/width", 260))
    readonly property int narrowWidth: 56
    // Collapsed bars peek open on hover, after a short pause. Not right after collapsing it:
    // the mouse is still on it then, and it would spring straight back open.
    property bool peek: false
    readonly property bool narrow: collapsed && !peek
    // Room the page leaves for the bar. A peeking bar floats over the page instead.
    readonly property real reservedWidth: collapsed ? narrowWidth : expandedWidth
    property alias toolbarSlot: slot
    property bool hasToolbar: false
    property bool searchOpen: false   // the tab search box (shortcut or Ctrl+Shift+A)
    // "Now playing": { tabId, icon, tabTitle, title, artist, playing, video, muted, poppedOut } or null.
    property var media: null

    signal newTabRequested()
    signal tabMenuRequested(int tabId)
    signal groupMenuRequested(int groupId)
    signal muteToggled(int tabId)
    signal panelRequested(string name)
    signal mediaAction(string action)   // "toggle" | "mute" | "pip" | "focus"

    function toggle() {
        collapsed = !collapsed
        peek = false
        peekTimer.stop()
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
    // The footer shortcuts: what each one shows and does.
    readonly property var shortcutInfo: ({
        bookmarks: { icon: "star", label: qsTr("Bookmarks"), tip: qsTr("Bookmarks (Ctrl+Shift+O)") },
        history: { icon: "history", label: qsTr("History"), tip: qsTr("History (Ctrl+H)") },
        downloads: { icon: "download", label: qsTr("Downloads"), tip: qsTr("Downloads (Ctrl+J)") },
        passwords: { icon: "key", label: qsTr("Passwords"), tip: qsTr("Passwords") },
        search: { icon: "search", label: qsTr("Search tabs"), tip: qsTr("Search tabs (Ctrl+Shift+A)") },
        settings: { icon: "settings", label: qsTr("Settings"), tip: qsTr("Settings (Ctrl+,)") }
    })
    function runShortcut(name) {
        if (name === "search") searchOpen ? (searchOpen = false, search.text = "") : focusSearch()
        else panelRequested(name)
    }

    width: narrow ? narrowWidth : expandedWidth
    Behavior on width {
        enabled: !resizer.pressed
        NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
    }
    color: "transparent"
    clip: true
    Fill {   // its background (Appearance > Backgrounds); see-through over a wallpaper if you like
        z: -1
        anchors.fill: parent
        spec: Theme.sidebarFill
        base: Theme.glass ? Qt.rgba(Theme.sidebar.r, Theme.sidebar.g, Theme.sidebar.b, Theme.glassTint) : Theme.sidebar
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered && sidebar.collapsed) peekTimer.restart()
            else { peekTimer.stop(); sidebar.peek = false }
        }
    }
    Timer { id: peekTimer; interval: 260; onTriggered: sidebar.peek = hover.hovered && sidebar.collapsed }

    // A hairline on the inner edge; a soft shadow while it floats over the page.
    Rectangle {
        x: Theme.tabsOnRight ? 0 : parent.width - 1
        width: 1
        height: parent.height
        color: Theme.line
    }
    Rectangle {
        visible: sidebar.collapsed && sidebar.peek
        x: Theme.tabsOnRight ? -8 : parent.width
        width: 8
        height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.tabsOnRight ? "transparent" : Qt.rgba(0, 0, 0, 0.25) }
            GradientStop { position: 1; color: Theme.tabsOnRight ? Qt.rgba(0, 0, 0, 0.25) : "transparent" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.bottomMargin: 8
        spacing: Theme.gap

        // ---- Logo row: lines up with the toolbar beside it ----
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            Image {
                id: mark
                x: sidebar.narrow ? (parent.width - width) / 2 : 6
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/logo/f1int.svg"
                sourceSize: Qt.size(40, 40)
                width: 20
                height: 20
                Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            }
            Text {
                anchors.left: mark.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: !sidebar.narrow
                text: "f1int"
                color: Theme.fg
                font.family: Theme.dotFont
                font.pixelSize: Theme.px(17)
                font.weight: Font.Black
            }
            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !sidebar.narrow
                iconName: "sidebar"
                iconColor: Theme.dim
                tip: sidebar.collapsed ? qsTr("Keep the tab bar open (Ctrl+Shift+S)") : qsTr("Collapse the tab bar (Ctrl+Shift+S)")
                onClicked: sidebar.toggle()
            }
            MouseArea {   // narrow: click the logo to open the bar again
                anchors.fill: parent
                visible: sidebar.narrow
                cursorShape: Qt.PointingHandCursor
                onClicked: sidebar.toggle()
                ToolTip.visible: containsMouse
                ToolTip.text: qsTr("Open the tab bar (Ctrl+Shift+S)")
                hoverEnabled: true
            }
        }

        Item {
            id: slot
            visible: sidebar.hasToolbar && !sidebar.narrow
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 82 : 0
        }

        // ---- Search open tabs ----
        TextField {
            id: search
            visible: (sidebar.searchOpen || text !== "") && !sidebar.narrow
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
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
            }
            Icon { x: 11; anchors.verticalCenter: parent.verticalCenter; glyph: "search"; sourceSize: Qt.size(14, 14); color: Theme.dim }
            Keys.onEscapePressed: { text = ""; focus = false; sidebar.searchOpen = false }
        }

        // ---- Pinned sites: an icon grid ----
        GridView {
            id: pinned
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            visible: Theme.showPinned && count > 0
            interactive: false
            cellWidth: sidebar.narrow ? width : Math.floor(width / 4)
            cellHeight: 44
            model: TabFilter { sourceModel: sidebar.tabs; pinned: true; text: search.text }
            delegate: PinnedTile { tabs: sidebar.tabs; onMenuRequested: sidebar.tabMenuRequested(tabId) }
            moveDisplaced: Transition { NumberAnimation { properties: "x,y"; duration: Theme.anim } }
        }


        // ---- Tabs, with group headers ----
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.tabGap
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
            // New tab: right under the last tab (scrolls with them).
            footer: Item {
                width: list.width
                height: Theme.showNewTabRow ? Theme.rowHeight + Theme.tabGap : 0
            Rectangle {
            visible: Theme.showNewTabRow
            y: Theme.tabGap
            width: list.width
            height: Theme.rowHeight
            radius: Theme.tabRadius
            color: newTabMouse.pressed ? Theme.press : newTabHover.hovered && Theme.hoverEffects ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.anim } }
            HoverHandler { id: newTabHover; cursorShape: Qt.PointingHandCursor }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("New tab")
            Rectangle {   // the plus sits in a small outlined square: a bit of geometry
                x: sidebar.narrow ? (parent.width - width) / 2 : 6
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: Math.min(6, Theme.radius)
                color: "transparent"
                border.width: 1
                border.color: Theme.line
                Icon { anchors.centerIn: parent; glyph: "plus"; sourceSize: Qt.size(14, 14); color: Theme.fg }
            }
            Text {
                x: 40
                anchors.verticalCenter: parent.verticalCenter
                visible: !sidebar.narrow
                text: qsTr("New tab")
                color: Theme.fg
                font.pixelSize: Theme.px(13)
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: !sidebar.narrow && newTabHover.hovered
                text: Qt.platform.os === "osx" ? "⌘T" : "Ctrl T"
                color: Theme.dim
                font.family: Theme.numberFont
                font.pixelSize: Theme.px(12)
            }
            MouseArea { id: newTabMouse; anchors.fill: parent; onClicked: sidebar.newTabRequested() }
        }
            }
            ScrollBar.vertical: ScrollBar { width: 4; policy: ScrollBar.AsNeeded }

            Text {   // nothing matches the search
                anchors.centerIn: parent
                visible: list.count === 0 && search.text !== ""
                text: qsTr("No tabs match \"%1\"").arg(search.text)
                color: Theme.dim
                font.pixelSize: Theme.px(12)
            }
        }

        // ---- Now playing: the tab that last played sound, with its controls ----
        Rectangle {
            id: nowPlaying
            visible: sidebar.media !== null && !sidebar.narrow
            Layout.fillWidth: true
            implicitHeight: 56
            radius: Theme.radius
            color: Theme.field
            readonly property var m: sidebar.media || ({})
            Rectangle {   // a small accent bar while it plays
                x: 0
                width: 3
                height: parent.height * 0.5
                anchors.verticalCenter: parent.verticalCenter
                radius: 1.5
                color: Theme.accent2
                visible: nowPlaying.m.playing === true
            }
            Image {   // album art when the site gives it, else the site's icon
                id: mediaIcon
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: nowPlaying.m.art ? 36 : 16
                height: width
                sourceSize: Qt.size(72, 72)
                fillMode: Image.PreserveAspectCrop
                source: nowPlaying.m.art || nowPlaying.m.icon || ""
            }
            Column {
                anchors.left: mediaIcon.right
                anchors.leftMargin: 10
                anchors.right: mediaButtons.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    width: parent.width
                    text: nowPlaying.m.title || nowPlaying.m.tabTitle || ""
                    color: Theme.fg
                    font.pixelSize: Theme.px(12)
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: nowPlaying.m.artist || (nowPlaying.m.title ? nowPlaying.m.tabTitle : qsTr("Playing in a tab"))
                    color: Theme.dim
                    font.pixelSize: Theme.px(11)
                    elide: Text.ElideRight
                }
            }
            MouseArea {   // click the words to go to the tab
                anchors.left: parent.left
                anchors.right: mediaButtons.left
                height: parent.height
                cursorShape: Qt.PointingHandCursor
                onClicked: sidebar.mediaAction("focus")
            }
            Row {
                id: mediaButtons
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                IconButton {
                    visible: nowPlaying.m.canSkip === true
                    implicitWidth: 26
                    iconName: "back"; iconSize: 14
                    tip: qsTr("Previous")
                    onClicked: sidebar.mediaAction("previous")
                }
                IconButton {
                    implicitWidth: 26
                    iconName: nowPlaying.m.playing ? "pause" : "play"
                    tip: nowPlaying.m.playing ? qsTr("Pause") : qsTr("Play")
                    onClicked: sidebar.mediaAction("toggle")
                }
                IconButton {
                    visible: nowPlaying.m.canSkip === true
                    implicitWidth: 26
                    iconName: "forward"; iconSize: 14
                    tip: qsTr("Next")
                    onClicked: sidebar.mediaAction("next")
                }
                IconButton {
                    visible: nowPlaying.m.video === true
                    iconName: "pip"
                    iconColor: nowPlaying.m.poppedOut ? Theme.accent : Theme.fg
                    tip: nowPlaying.m.poppedOut ? qsTr("Put the video back") : qsTr("Pop out the video")
                    onClicked: sidebar.mediaAction("pip")
                }
                IconButton {
                    iconName: nowPlaying.m.muted ? "muted" : "speaker"
                    tip: nowPlaying.m.muted ? qsTr("Unmute") : qsTr("Mute")
                    onClicked: sidebar.mediaAction("mute")
                }
            }
        }

        // ---- Footer: your shortcuts, and f1int's memory use ----
        Rectangle {
            visible: !sidebar.narrow
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.line
        }
        // Labels on: one row per shortcut. Labels off: a row of icons.
        Repeater {
            model: Theme.sidebarLabels && !sidebar.narrow ? Theme.shortcuts : []
            Rectangle {
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: Theme.radius
                color: rowHover.hovered && Theme.hoverEffects ? Theme.hover : "transparent"
                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                Accessible.role: Accessible.Button
                Accessible.name: sidebar.shortcutInfo[modelData].label
                Icon { x: 9; anchors.verticalCenter: parent.verticalCenter; glyph: sidebar.shortcutInfo[parent.modelData].icon; sourceSize: Qt.size(Theme.iconSize, Theme.iconSize); color: Theme.dim }
                Text { x: 38; anchors.verticalCenter: parent.verticalCenter; text: sidebar.shortcutInfo[parent.modelData].label; color: Theme.fg; font.pixelSize: Theme.px(13) }
                MouseArea { anchors.fill: parent; onClicked: sidebar.runShortcut(parent.modelData) }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: !sidebar.narrow
            Repeater {
                model: Theme.sidebarLabels ? [] : Theme.shortcuts
                IconButton {
                    required property string modelData
                    implicitWidth: Theme.iconSize + 16
                    implicitHeight: Theme.iconSize + 16
                    iconSize: Theme.iconSize
                    iconName: sidebar.shortcutInfo[modelData].icon
                    iconColor: modelData === "search" && sidebar.searchOpen ? Theme.accent : Theme.dim
                    tip: sidebar.shortcutInfo[modelData].tip
                    onClicked: sidebar.runShortcut(modelData)
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                id: ram
                visible: Theme.showRam && mb > 0
                property int mb: 0
                text: mb + " MB"
                color: Theme.dim
                font.family: Theme.numberFont
                font.pixelSize: Theme.px(13)
                font.weight: Font.Bold
                Layout.rightMargin: 6
                function refresh() { mb = Math.round(Browser.memoryInfo().total / 1048576) }
                Component.onCompleted: refresh()
                Timer { interval: 10000; repeat: true; running: Theme.showRam && Qt.application.state === Qt.ApplicationActive; onTriggered: ram.refresh() }
                HoverHandler { id: ramHover }
                ToolTip.visible: ramHover.hovered
                ToolTip.text: qsTr("Memory used by f1int (open Memory from the menu for details)")
            }
        }
        // Narrow: just a button to open the bar again.
        IconButton {
            visible: sidebar.narrow
            Layout.alignment: Qt.AlignHCenter
            iconName: "sidebar"
            iconColor: Theme.dim
            tip: qsTr("Open the tab bar (Ctrl+Shift+S)")
            onClicked: sidebar.toggle()
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
