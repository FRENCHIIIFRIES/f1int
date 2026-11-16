import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtWebEngine
import f1int

// One browser window: tab bar on the left, toolbar + page on the right.
// The tab *list* lives in C++ (Browser.tabs); the web *pages* live here, one per tab,
// created the first time a tab is opened.
ApplicationWindow {
    id: window
    width: 1280
    height: 820
    visible: true
    color: Theme.bg
    title: (view && view.title ? view.title : qsTr("New tab")) + " – f1int"
    palette.toolTipBase: Theme.surface
    palette.toolTipText: Theme.fg

    property var pages: ({})            // tab id -> WebView
    property WebEngineView view: null   // the open tab's page
    property string hoveredLink: ""
    readonly property bool fullScreen: visibility === Window.FullScreen

    // ---------- tab and page helpers ----------
    function pageFor(id, load) {
        let page = pages[id]
        if (!page) {
            const tab = Browser.tabs.tab(id)
            page = pageComponent.createObject(pageArea, { tabId: id, audioMuted: tab.muted === true })
            pages[id] = page
            if (load !== false && tab.url && tab.url.toString() !== "")
                page.url = tab.url
        }
        return page
    }
    function newTab(url, background, afterId) {
        return Browser.tabs.add(url || "about:blank", !background, afterId === undefined ? -1 : afterId)
    }
    function setMuted(id, muted) {
        if (pages[id]) pages[id].audioMuted = muted
        Browser.tabs.update(id, { muted: muted })
    }
    function selectByOffset(step) {
        const n = Browser.tabs.count
        const row = Browser.tabs.rowOf(Browser.tabs.currentId)
        Browser.tabs.currentId = Browser.tabs.idAt((row + step + n) % n)
    }
    // A page asked to open a link in a new tab / window (middle-click, target=_blank, popups).
    function handleOpen(request, fromId) {
        const background = request.destination === WebEngineNewWindowRequest.InNewBackgroundTab
        const id = Browser.tabs.add(request.requestedUrl, false, fromId)
        request.openIn(pageFor(id, false))   // keeps the link between the pages (window.opener)
        if (!background)
            Browser.tabs.currentId = id
    }
    function zoom(step) {
        if (!view) return
        const levels = [0.25, 0.33, 0.5, 0.67, 0.75, 0.8, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5]
        let i = levels.findIndex(l => l >= view.zoomFactor - 0.001)
        view.zoomFactor = step === 0 ? 1 : levels[Math.max(0, Math.min(levels.length - 1, i + step))]
    }
    function toggleFullScreen() { fullScreen ? showNormal() : showFullScreen() }
    function openDevTools() {
        devTools.active = true
        devTools.item.inspect(view)
    }
    function lastTabOfGroup(groupId) {
        let last = -1
        for (let r = 0; r < Browser.tabs.count; ++r)
            if (Browser.tabs.tab(Browser.tabs.idAt(r)).groupId === groupId)
                last = Browser.tabs.idAt(r)
        return last
    }

    Connections {
        target: Browser.tabs
        function onCurrentIdChanged() {
            const id = Browser.tabs.currentId
            if (id < 0) { window.view = null; return }
            const page = window.pageFor(id)
            page.lifecycleState = WebEngineView.LifecycleState.Active   // wake it if it was asleep
            window.view = page
            page.forceActiveFocus()
        }
        function onTabClosed(id) {
            const page = window.pages[id]
            if (page) { delete window.pages[id]; page.destroy() }   // frees the page's memory
            if (Browser.tabs.count === 0) window.close()             // like Chrome: last tab closes the window
        }
    }
    Component.onCompleted: {
        const urls = Browser.startUrls
        for (let i = 0; i < urls.length; ++i)
            newTab(urls[i], i > 0)   // the first one opens, the rest wait in the background
        // UI test scripts (tests/ui/*.qml) run only when F1INT_UI_TEST names one.
        if (Browser.uiTestScript.toString() !== "")
            Qt.createComponent(Browser.uiTestScript).createObject(window, { win: window })
    }
    // For UI test scripts: reach the menus and panels by name.
    property alias sidebarItem: sidebar
    property alias tabMenuItem: tabMenu
    property alias groupPopupItem: groupPopup
    property alias mainMenuItem: mainMenu
    property alias toolbarItem: toolbar

    Component {
        id: pageComponent
        WebView {
            anchors.fill: parent
            onOpenRequested: (request) => window.handleOpen(request, tabId)
            onLinkHovered: (url) => window.hoveredLink = url.toString()
            onFullScreenRequested: (request) => {
                request.accept()
                request.toggleOn ? window.showFullScreen() : window.showNormal()
            }
        }
    }

    // ---------- layout ----------
    TabSidebar {
        id: sidebar
        z: 2   // when collapsed it floats over the page while hovered
        visible: !window.fullScreen
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        onNewTabRequested: { window.newTab(); toolbar.focusAddress() }
        onTabMenuRequested: (id) => tabMenu.openFor(id)
        onGroupMenuRequested: (id) => groupMenu.openFor(sidebar.groupInfo(id))
        onMuteToggled: (id) => window.setMuted(id, !Browser.tabs.tab(id).muted)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: window.fullScreen ? 0 : sidebar.reservedWidth
        spacing: 0

        Toolbar {
            id: toolbar
            Layout.fillWidth: true
            visible: !window.fullScreen
            view: window.view
            onMenuRequested: (button) => mainMenu.popup(button, button.width - mainMenu.width, button.height + 4)
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line; visible: !window.fullScreen }

        Item {
            id: pageArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Where a hovered link goes, bottom left (like other browsers).
            Rectangle {
                z: 5
                visible: window.hoveredLink !== ""
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 6
                width: Math.min(linkText.implicitWidth + 20, parent.width * 0.6)
                height: 24
                radius: 6
                color: Theme.surface
                border.width: 1
                border.color: Theme.line
                Text {
                    id: linkText
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: window.hoveredLink
                    color: Theme.dim
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                }
            }
            // Zoom level, shown when not 100%.
            Rectangle {
                z: 5
                visible: window.view !== null && Math.abs(window.view.zoomFactor - 1) > 0.001
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                width: zoomText.implicitWidth + 18
                height: 26
                radius: 13
                color: Theme.surface
                border.width: 1
                border.color: Theme.line
                Text {
                    id: zoomText
                    anchors.centerIn: parent
                    text: window.view ? Math.round(window.view.zoomFactor * 100) + "%" : ""
                    color: Theme.fg
                    font.family: Theme.dotFont
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
                MouseArea { anchors.fill: parent; onClicked: window.zoom(0) }
            }
        }
    }

    // ---------- menus and dialogs ----------
    component Separator: MenuSeparator {
        contentItem: Rectangle { implicitHeight: 1; color: Theme.line }
    }
    component PillButton: Button {
        id: pill
        property bool primary: false
        implicitHeight: 30
        contentItem: Text {
            text: pill.text
            color: pill.primary ? "#ffffff" : Theme.fg
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            implicitWidth: 76
            radius: 15
            color: pill.primary ? (pill.down ? Qt.darker(Theme.accent, 1.2) : Theme.accent)
                                : (pill.down ? Theme.press : pill.hovered ? Theme.hover : "transparent")
            border.width: pill.primary ? 0 : 1
            border.color: Theme.line
        }
    }

    F1Menu {
        id: mainMenu
        Action { text: qsTr("New tab"); onTriggered: { window.newTab(); toolbar.focusAddress() } }
        Action { text: qsTr("Reopen closed tab"); onTriggered: Browser.tabs.reopenClosed() }
        Action { text: qsTr("Search tabs"); onTriggered: sidebar.focusSearch() }
        Separator {}
        Action { text: qsTr("Zoom in"); onTriggered: window.zoom(1) }
        Action { text: qsTr("Zoom out"); onTriggered: window.zoom(-1) }
        Action { text: qsTr("Reset zoom"); onTriggered: window.zoom(0) }
        Action { text: window.fullScreen ? qsTr("Exit full screen") : qsTr("Full screen"); onTriggered: window.toggleFullScreen() }
        Separator {}
        Action { text: sidebar.collapsed ? qsTr("Keep tab bar open") : qsTr("Collapse tab bar"); onTriggered: sidebar.toggle() }
        Action { text: qsTr("Developer tools"); enabled: window.view !== null; onTriggered: window.openDevTools() }
    }

    F1Menu {
        id: tabMenu
        property int tabId: -1
        property var tab: ({})
        function openFor(id) { tabId = id; tab = Browser.tabs.tab(id); popup() }

        Action { text: qsTr("New tab below"); onTriggered: window.newTab("about:blank", false, tabMenu.tabId) }
        Action { text: qsTr("Reload"); onTriggered: window.pageFor(tabMenu.tabId).reload() }
        Action { text: qsTr("Duplicate"); onTriggered: Browser.tabs.duplicate(tabMenu.tabId) }
        Action { text: tabMenu.tab.pinned ? qsTr("Unpin") : qsTr("Pin"); onTriggered: Browser.tabs.setPinned(tabMenu.tabId, !tabMenu.tab.pinned) }
        Action { text: tabMenu.tab.muted ? qsTr("Unmute tab") : qsTr("Mute tab"); onTriggered: window.setMuted(tabMenu.tabId, !tabMenu.tab.muted) }
        Separator {}
        Action { text: qsTr("Add to new group…"); enabled: !tabMenu.tab.pinned; onTriggered: groupPopup.create(tabMenu.tabId) }
        F1Menu {
            id: moveToGroup
            title: qsTr("Move to group")
            enabled: !tabMenu.tab.pinned && Browser.tabs.groups.length > 0
            Instantiator {
                model: Browser.tabs.groups
                delegate: Action {
                    required property var modelData
                    text: modelData.name
                    onTriggered: Browser.tabs.setGroup(tabMenu.tabId, modelData.id)
                }
                onObjectAdded: (index, action) => moveToGroup.insertAction(index, action)
                onObjectRemoved: (index, action) => moveToGroup.removeAction(action)
            }
        }
        Action { text: qsTr("Remove from group"); enabled: tabMenu.tab.groupId >= 0; onTriggered: Browser.tabs.setGroup(tabMenu.tabId, -1) }
        Separator {}
        Action { text: qsTr("Close tab"); onTriggered: Browser.tabs.close(tabMenu.tabId) }
        Action { text: qsTr("Close other tabs"); onTriggered: Browser.tabs.closeOthers(tabMenu.tabId) }
    }

    F1Menu {
        id: groupMenu
        property var group: ({})
        function openFor(g) { group = g; popup() }

        Action { text: qsTr("New tab in group"); onTriggered: window.newTab("about:blank", false, window.lastTabOfGroup(groupMenu.group.id)) }
        Action { text: qsTr("Rename or recolour…"); onTriggered: groupPopup.edit(groupMenu.group) }
        Action { text: groupMenu.group.collapsed ? qsTr("Expand") : qsTr("Collapse"); onTriggered: Browser.tabs.editGroup(groupMenu.group.id, { collapsed: !groupMenu.group.collapsed }) }
        Separator {}
        Action { text: qsTr("Ungroup"); onTriggered: Browser.tabs.ungroup(groupMenu.group.id) }
        Action { text: qsTr("Close group"); onTriggered: Browser.tabs.closeGroup(groupMenu.group.id) }
    }

    // Name and colour for a new or existing tab group.
    Popup {
        id: groupPopup
        property int tabId: -1     // making a new group for this tab
        property int groupId: -1   // or editing this group
        property color chosen: Theme.groupColors[0]
        function create(id) {
            tabId = id; groupId = -1; nameField.text = ""
            chosen = Theme.groupColors[Browser.tabs.groups.length % Theme.groupColors.length]
            open()
        }
        function edit(g) { tabId = -1; groupId = g.id; nameField.text = g.name; chosen = g.color; open() }
        function save() {
            const name = nameField.text.trim() || qsTr("Group")
            if (groupId >= 0)
                Browser.tabs.editGroup(groupId, { name: name, color: chosen })
            else
                Browser.tabs.setGroup(tabId, Browser.tabs.addGroup(name, chosen))
            close()
        }

        modal: true
        anchors.centerIn: Overlay.overlay
        width: 320
        padding: 20
        onOpened: nameField.forceActiveFocus()
        background: Rectangle { color: Theme.surface; border.width: 1; border.color: Theme.line; radius: 16 }

        contentItem: ColumnLayout {
            spacing: 16
            Text {
                text: groupPopup.groupId >= 0 ? qsTr("EDIT GROUP") : qsTr("NEW GROUP")
                color: Theme.fg
                font.family: Theme.dotFont
                font.pixelSize: 22
                font.weight: Font.Black
            }
            TextField {
                id: nameField
                Layout.fillWidth: true
                implicitHeight: 34
                placeholderText: qsTr("Group name")
                placeholderTextColor: Theme.dim
                color: Theme.fg
                selectionColor: Theme.accent
                font.pixelSize: 13
                background: Rectangle { radius: 8; color: Theme.bg; border.width: 1; border.color: nameField.activeFocus ? Theme.dim : Theme.line }
                onAccepted: groupPopup.save()
            }
            Row {
                spacing: 10
                Repeater {
                    model: Theme.groupColors
                    Rectangle {
                        required property color modelData
                        width: 24
                        height: 24
                        radius: 12
                        color: "transparent"
                        border.width: Qt.colorEqual(groupPopup.chosen, modelData) ? 1.5 : 0
                        border.color: Theme.fg
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: qsTr("Colour %1").arg(modelData)
                        Rectangle { anchors.centerIn: parent; width: 16; height: 16; radius: 8; color: parent.modelData }
                        MouseArea { anchors.fill: parent; onClicked: groupPopup.chosen = parent.modelData }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                PillButton { text: qsTr("Cancel"); onClicked: groupPopup.close() }
                PillButton { text: qsTr("Save"); primary: true; onClicked: groupPopup.save() }
            }
        }
    }

    // Developer tools in their own window, created only when first opened.
    Loader {
        id: devTools
        active: false
        sourceComponent: Window {
            width: 960
            height: 640
            color: Theme.bg
            title: qsTr("Developer tools – f1int")
            function inspect(page) { devView.inspectedView = page; show(); raise() }
            WebEngineView { id: devView; anchors.fill: parent; profile: Browser.profile }
        }
    }

    // ---------- keyboard shortcuts (same as Chrome; on Mac "Ctrl" means Cmd) ----------
    Shortcut { sequences: ["Ctrl+T"]; onActivated: { window.newTab(); toolbar.focusAddress() } }
    Shortcut { sequences: ["Ctrl+W", "Ctrl+F4"]; onActivated: Browser.tabs.close(Browser.tabs.currentId) }
    Shortcut { sequence: "Ctrl+Shift+T"; onActivated: Browser.tabs.reopenClosed() }
    Shortcut { sequences: ["Ctrl+Tab", "Ctrl+PgDown"]; onActivated: window.selectByOffset(1) }
    Shortcut { sequences: ["Ctrl+Shift+Tab", "Ctrl+PgUp"]; onActivated: window.selectByOffset(-1) }
    Instantiator {   // Ctrl+1 … Ctrl+8: that tab; Ctrl+9: the last tab
        model: 9
        delegate: Shortcut {
            required property int index
            sequence: "Ctrl+" + (index + 1)
            onActivated: Browser.tabs.currentId = Browser.tabs.idAt(index === 8 ? Browser.tabs.count - 1 : index)
        }
    }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: sidebar.toggle() }
    Shortcut { sequence: "Ctrl+Shift+A"; onActivated: sidebar.focusSearch() }
    Shortcut { sequences: ["Ctrl+L", "Alt+D", "F6"]; onActivated: toolbar.focusAddress() }
    Shortcut { sequences: ["Alt+Left", "Ctrl+["]; onActivated: if (window.view) window.view.goBack() }
    Shortcut { sequences: ["Alt+Right", "Ctrl+]"]; onActivated: if (window.view) window.view.goForward() }
    Shortcut { sequences: ["F5", "Ctrl+R"]; onActivated: if (window.view) window.view.reload() }
    Shortcut { sequences: ["Ctrl+F5", "Shift+F5", "Ctrl+Shift+R"]; onActivated: if (window.view) window.view.reloadAndBypassCache() }
    Shortcut { sequence: "Alt+Home"; onActivated: if (window.view) window.view.url = Browser.homeUrl }
    Shortcut { sequence: "Esc"; enabled: window.view !== null && window.view.loading; onActivated: window.view.stop() }
    Shortcut { sequences: ["Ctrl+=", "Ctrl++"]; onActivated: window.zoom(1) }
    Shortcut { sequence: "Ctrl+-"; onActivated: window.zoom(-1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: window.zoom(0) }
    Shortcut { sequence: "F11"; onActivated: window.toggleFullScreen() }
    Shortcut { sequences: ["F12", "Ctrl+Shift+I"]; enabled: window.view !== null; onActivated: window.openDevTools() }
}
