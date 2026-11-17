import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import QtWebEngine
import f1int

// One browser window: tab bar on the left, toolbar + page on the right, panels on the right edge.
// Each window has its own tab list (`tabs`); the web *pages* live here, one per tab,
// created the first time a tab is opened. Incognito windows use a throwaway profile.
ApplicationWindow {
    id: window
    property bool incognito: false                // set when the window is created
    property TabModel tabs: TabModel {}
    readonly property var profile: incognito ? Browser.createIncognitoProfile(window) : Browser.profile

    property var pages: ({})            // tab id -> WebView
    property WebEngineView view: null   // the open tab's page
    property string hoveredLink: ""
    property string panel: ""           // open side panel: bookmarks | history | downloads | settings | memory
    property var downloads: []          // newest first
    property var lastActive: ({})       // tab id -> when it was last the open tab (ms)
    property int previousTab: -1
    readonly property bool fullScreen: visibility === Window.FullScreen
    readonly property int activeDownloads: downloads.filter(d => d.state === WebEngineDownloadRequest.DownloadInProgress).length

    width: 1280
    height: 820
    visible: true
    color: Theme.bg
    title: (view && view.title ? view.title : qsTr("New tab")) + (incognito ? " – f1int Incognito" : " – f1int")
    palette.toolTipBase: Theme.surface
    palette.toolTipText: Theme.fg

    // ---------- tabs and pages ----------
    function setting(key, fallback) { void Browser.settingsRevision; return Browser.setting(key, fallback) }
    // New tabs: f1int's own page (default), a blank page, the home page, or any address.
    function newTabUrl() {
        const mode = setting("newtab/mode", "f1int")
        return mode === "home" ? Browser.homeUrl : mode === "custom" ? Browser.urlFromInput(setting("newtab/url", "")) : "about:blank"
    }
    readonly property bool showNewTabPage: view !== null && setting("newtab/mode", "f1int") === "f1int"
                                           && (view.url.toString() === "" || view.url.toString() === "about:blank")
    function openNewTab() {
        newTab()
        // Focus the new tab page's search bar if it wants that, otherwise the address bar.
        Qt.callLater(() => {
            const ntp = newTabPage.item
            if (ntp && ntp.cfg.search.on && ntp.cfg.search.autofocus) ntp.focusSearch()
            else toolbar.focusAddress()
        })
    }

    function pageFor(id, load) {
        let page = pages[id]
        if (!page) {
            const tab = tabs.tab(id)
            page = pageComponent.createObject(pageArea, { tabId: id, tabs: tabs, incognito: incognito,
                                                          profile: profile, audioMuted: tab.muted === true })
            pages[id] = page
            tabs.update(id, { asleep: false })
            // Blank tabs load nothing: no Chromium page process until you go somewhere.
            if (load !== false && tab.url && tab.url.toString() !== "" && tab.url.toString() !== "about:blank")
                page.url = tab.url
        }
        return page
    }
    function newTab(url, background, afterId) {
        return tabs.add(url || newTabUrl(), !background, afterId === undefined ? -1 : afterId)
    }
    function setMuted(id, muted) {
        if (pages[id]) pages[id].audioMuted = muted
        tabs.update(id, { muted: muted })
    }
    function selectByOffset(step) {
        const n = tabs.count
        tabs.currentId = tabs.idAt((tabs.rowOf(tabs.currentId) + step + n) % n)
    }
    // A page asked to open a link in a new tab / window (middle-click, target=_blank, popups).
    function handleOpen(request, fromId) {
        const background = request.destination === WebEngineNewWindowRequest.InNewBackgroundTab
        const id = tabs.add(request.requestedUrl, false, fromId)
        request.openIn(pageFor(id, false))   // keeps the link between the pages (window.opener)
        if (!background)
            tabs.currentId = id
    }
    function zoom(step) {
        if (!view) return
        const levels = [0.25, 0.33, 0.5, 0.67, 0.75, 0.8, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5]
        const i = levels.findIndex(l => l >= view.zoomFactor - 0.001)
        view.zoomFactor = step === 0 ? 1 : levels[Math.max(0, Math.min(levels.length - 1, i + step))]
    }
    function toggleFullScreen() { fullScreen ? showNormal() : showFullScreen() }
    function openDevTools() {
        devTools.active = true
        devTools.item.inspect(view)
    }
    function lastTabOfGroup(groupId) {
        let last = -1
        for (let r = 0; r < tabs.count; ++r)
            if (tabs.tab(tabs.idAt(r)).groupId === groupId)
                last = tabs.idAt(r)
        return last
    }
    function showPanel(name) { panel = panel === name ? "" : name }

    // ---------- tab sleeping (memory saver) ----------
    // Background tabs are Frozen (page kept, stops running) after a few minutes, and
    // Discarded (memory freed, reloads when clicked) after longer. Tabs playing sound,
    // or with form input that wasn't sent, are left alone. `force` = "sleep all now".
    // Chromium only goes one step at a time (Active -> Frozen -> Discarded), so "sleep all"
    // freezes first and finishes the job a moment later.
    function sleepIdleTabs(force, finishing) {
        if (force && !finishing) sleepAgain.restart()
        const level = setting("memory/saver", "balanced")
        if (level === "off" && !force) return
        const freezeMs = (level === "max" ? 0.5 : Number(setting("memory/freezeMinutes", 2))) * 60000
        const discardMs = (level === "max" ? 2 : Number(setting("memory/discardMinutes", 10))) * 60000
        const now = Date.now()
        for (const key in pages) {
            const page = pages[key]
            const id = Number(key)
            if (id === tabs.currentId || page.recentlyAudible) continue
            const idle = now - (lastActive[key] || now)
            let target = force || idle >= discardMs ? WebEngineView.LifecycleState.Discarded
                       : idle >= freezeMs ? WebEngineView.LifecycleState.Frozen : WebEngineView.LifecycleState.Active
            // Chromium knows when going further would lose something (e.g. unsent forms).
            target = Math.min(target, page.recommendedState)
            if (target === WebEngineView.LifecycleState.Active || page.lifecycleState >= target) continue
            const apply = () => { if (id !== tabs.currentId) page.lifecycleState = target }
            // A frozen page can't run scripts; its form check already happened before freezing.
            if (page.lifecycleState === WebEngineView.LifecycleState.Frozen) apply()
            else page.hasUnsavedInput(edited => { if (!edited) apply() })
        }
    }
    Timer { interval: 15000; repeat: true; running: true; onTriggered: window.sleepIdleTabs(false) }
    Timer { id: sleepAgain; interval: 1000; onTriggered: window.sleepIdleTabs(true, true) }

    Connections {
        target: window.tabs
        function onCurrentIdChanged() {
            const now = Date.now()
            if (window.previousTab >= 0) window.lastActive[window.previousTab] = now
            const id = window.tabs.currentId
            window.previousTab = id
            if (id < 0) { window.view = null; return }
            const page = window.pageFor(id)
            page.lifecycleState = WebEngineView.LifecycleState.Active   // wake it if it was asleep
            window.lastActive[id] = now
            window.view = page
            page.forceActiveFocus()
        }
        function onTabClosed(id) {
            const page = window.pages[id]
            if (page) { delete window.pages[id]; page.destroy() }   // frees the page's memory
            delete window.lastActive[id]
            if (window.tabs.count === 0) window.close()        // like Chrome: last tab closes the window
        }
    }
    Connections {
        target: window.profile
        function onDownloadRequested(download) {
            // Normal windows share one profile, so each hears about every download: the
            // first window to see it takes it, the others skip it once it's accepted.
            if (download.state !== WebEngineDownloadRequest.DownloadRequested)
                return
            download.accept()
            window.downloads = [download].concat(window.downloads)
            window.panel = "downloads"
        }
    }

    onClosing: {
        Browser.unregisterWindow(tabs)
        for (const key in pages) pages[key].destroy()   // free the pages; the window object itself stays tiny
        pages = {}
    }

    Component.onCompleted: {
        // Remember when the user types into a form, so memory saver leaves that tab awake.
        // Runs in a separate script world: pages can't see or change it.
        if (profile.userScripts.find("f1int-edit-tracker").length === 0) {
            const s = WebEngine.script()
            s.name = "f1int-edit-tracker"
            s.sourceCode = "addEventListener('input', () => { window.__f1intEdited = true }, true);" +
                           "addEventListener('submit', () => { window.__f1intEdited = false }, true);"
            s.injectionPoint = WebEngineScript.DocumentCreation
            s.worldId = WebEngineScript.ApplicationWorld
            s.runsOnSubFrames = true
            profile.userScripts.insert(s)
        }

        const restored = Browser.registerWindow(tabs, incognito)   // reopens last session's tabs
        const start = Browser.takeStartUrls()
        for (let i = 0; i < start.urls.length; ++i)
            newTab(start.urls[i], i > 0 || restored)
        if (!restored && start.urls.length === 0)
            newTab(start.first ? Browser.homeUrl : newTabUrl())

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
    property alias findBarItem: findBar

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
        tabs: window.tabs
        z: 2   // when collapsed it floats over the page while hovered
        visible: !window.fullScreen
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        onNewTabRequested: window.openNewTab()
        onTabMenuRequested: (id) => tabMenu.openFor(id)
        onGroupMenuRequested: (id) => groupMenu.openFor(sidebar.groupInfo(id))
        onMuteToggled: (id) => window.setMuted(id, !window.tabs.tab(id).muted)
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
            incognito: window.incognito
            activeDownloads: window.activeDownloads
            onMenuRequested: (button) => mainMenu.popup(button, button.width - mainMenu.width, button.height + 4)
            onPanelRequested: (name) => window.showPanel(name)
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line; visible: !window.fullScreen }
        FindBar { id: findBar; Layout.fillWidth: true; view: window.view }

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
            // Zoom level, shown when not 100%. Click to reset.
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

            // The new tab page, on top of an empty tab's (unloaded) page.
            Loader {
                id: newTabPage
                z: 4
                anchors.fill: parent
                active: window.showNewTabPage
                sourceComponent: NewTabPage { view: window.view; incognito: window.incognito }
            }

            // Side panel on the right: bookmarks / history / downloads, settings, memory.
            Loader {
                z: 6
                active: window.panel !== ""
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.min(400, parent.width - 40)
                sourceComponent: window.panel === "settings" ? settingsPanel
                               : window.panel === "memory" ? memoryPanel : libraryPanel
            }
        }
    }

    Component {
        id: libraryPanel
        LibraryPanel {
            page: window.panel
            downloads: window.downloads
            onPageChanged: if (page !== window.panel) window.panel = page
            onOpenUrl: (url) => window.newTab(url)
            onCloseRequested: window.panel = ""
        }
    }
    Component { id: settingsPanel; SettingsPanel { onCloseRequested: window.panel = "" } }
    Component {
        id: memoryPanel
        MemoryPanel {
            tabs: window.tabs
            pages: window.pages
            onSleepAllRequested: window.sleepIdleTabs(true)
            onCloseRequested: window.panel = ""
        }
    }

    // ---------- menus and dialogs ----------
    component Separator: MenuSeparator {
        contentItem: Rectangle { implicitHeight: 1; color: Theme.line }
    }

    F1Menu {
        id: mainMenu
        Action { text: qsTr("New tab"); onTriggered: window.openNewTab() }
        Action { text: qsTr("New window"); onTriggered: Browser.newWindow(false) }
        Action { text: qsTr("New incognito window"); onTriggered: Browser.newWindow(true) }
        Separator {}
        Action { text: qsTr("Bookmarks"); onTriggered: window.showPanel("bookmarks") }
        Action { text: qsTr("History"); onTriggered: window.showPanel("history") }
        Action { text: qsTr("Downloads"); onTriggered: window.showPanel("downloads") }
        Action { text: qsTr("Reopen closed tab"); onTriggered: window.tabs.reopenClosed() }
        Separator {}
        Action { text: qsTr("Find in page"); enabled: window.view !== null; onTriggered: findBar.open() }
        Action { text: qsTr("Save page as PDF"); enabled: window.view !== null; onTriggered: pdfDialog.open() }
        Action { text: qsTr("Zoom in"); onTriggered: window.zoom(1) }
        Action { text: qsTr("Zoom out"); onTriggered: window.zoom(-1) }
        Action { text: window.fullScreen ? qsTr("Exit full screen") : qsTr("Full screen"); onTriggered: window.toggleFullScreen() }
        Separator {}
        Action { text: qsTr("Memory"); onTriggered: window.showPanel("memory") }
        Action { text: qsTr("Settings"); onTriggered: window.showPanel("settings") }
        Action { text: qsTr("Developer tools"); enabled: window.view !== null; onTriggered: window.openDevTools() }
    }

    F1Menu {
        id: tabMenu
        property int tabId: -1
        property var tab: ({})
        function openFor(id) { tabId = id; tab = window.tabs.tab(id); popup() }

        Action { text: qsTr("New tab below"); onTriggered: window.newTab("", false, tabMenu.tabId) }
        Action { text: qsTr("Reload"); onTriggered: window.pageFor(tabMenu.tabId).reload() }
        Action { text: qsTr("Duplicate"); onTriggered: window.tabs.duplicate(tabMenu.tabId) }
        Action { text: tabMenu.tab.pinned ? qsTr("Unpin") : qsTr("Pin"); onTriggered: window.tabs.setPinned(tabMenu.tabId, !tabMenu.tab.pinned) }
        Action { text: tabMenu.tab.muted ? qsTr("Unmute tab") : qsTr("Mute tab"); onTriggered: window.setMuted(tabMenu.tabId, !tabMenu.tab.muted) }
        Action {
            text: qsTr("Put tab to sleep")
            enabled: tabMenu.tabId !== window.tabs.currentId && window.pages[tabMenu.tabId] !== undefined
            onTriggered: window.pages[tabMenu.tabId].lifecycleState = WebEngineView.LifecycleState.Discarded
        }
        Separator {}
        Action { text: qsTr("Add to new group…"); enabled: !tabMenu.tab.pinned; onTriggered: groupPopup.create(tabMenu.tabId) }
        F1Menu {
            id: moveToGroup
            title: qsTr("Move to group")
            enabled: !tabMenu.tab.pinned && window.tabs.groups.length > 0
            Instantiator {
                model: window.tabs.groups
                delegate: Action {
                    required property var modelData
                    text: modelData.name
                    onTriggered: window.tabs.setGroup(tabMenu.tabId, modelData.id)
                }
                onObjectAdded: (index, action) => moveToGroup.insertAction(index, action)
                onObjectRemoved: (index, action) => moveToGroup.removeAction(action)
            }
        }
        Action { text: qsTr("Remove from group"); enabled: tabMenu.tab.groupId >= 0; onTriggered: window.tabs.setGroup(tabMenu.tabId, -1) }
        Separator {}
        Action { text: qsTr("Close tab"); onTriggered: window.tabs.close(tabMenu.tabId) }
        Action { text: qsTr("Close other tabs"); onTriggered: window.tabs.closeOthers(tabMenu.tabId) }
    }

    F1Menu {
        id: groupMenu
        property var group: ({})
        function openFor(g) { group = g; popup() }

        Action { text: qsTr("New tab in group"); onTriggered: window.newTab("", false, window.lastTabOfGroup(groupMenu.group.id)) }
        Action { text: qsTr("Rename or recolour…"); onTriggered: groupPopup.edit(groupMenu.group) }
        Action { text: groupMenu.group.collapsed ? qsTr("Expand") : qsTr("Collapse"); onTriggered: window.tabs.editGroup(groupMenu.group.id, { collapsed: !groupMenu.group.collapsed }) }
        Separator {}
        Action { text: qsTr("Ungroup"); onTriggered: window.tabs.ungroup(groupMenu.group.id) }
        Action { text: qsTr("Close group"); onTriggered: window.tabs.closeGroup(groupMenu.group.id) }
    }

    // Name and colour for a new or existing tab group.
    Popup {
        id: groupPopup
        property int tabId: -1     // making a new group for this tab
        property int groupId: -1   // or editing this group
        property color chosen: Theme.groupColors[0]
        function create(id) {
            tabId = id; groupId = -1; nameField.text = ""
            chosen = Theme.groupColors[window.tabs.groups.length % Theme.groupColors.length]
            open()
        }
        function edit(g) { tabId = -1; groupId = g.id; nameField.text = g.name; chosen = g.color; open() }
        function save() {
            const name = nameField.text.trim() || qsTr("Group")
            if (groupId >= 0)
                window.tabs.editGroup(groupId, { name: name, color: chosen })
            else
                window.tabs.setGroup(tabId, window.tabs.addGroup(name, chosen))
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
            Ui.Field {
                id: nameField
                Layout.fillWidth: true
                placeholderText: qsTr("Group name")
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
                Ui.Pill { text: qsTr("Cancel"); onClicked: groupPopup.close() }
                Ui.Pill { text: qsTr("Save"); primary: true; onClicked: groupPopup.save() }
            }
        }
    }

    // Save page as PDF (Ctrl+P).
    FileDialog {
        id: pdfDialog
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("PDF files (*.pdf)")]
        defaultSuffix: "pdf"
        onAccepted: if (window.view) window.view.printToPdf(Browser.localPath(selectedFile))
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
            WebEngineView { id: devView; anchors.fill: parent; profile: window.profile }
        }
    }

    // ---------- keyboard shortcuts (same as Chrome; on Mac "Ctrl" means Cmd) ----------
    Shortcut { sequence: "Ctrl+T"; onActivated: window.openNewTab() }
    Shortcut { sequence: "Ctrl+N"; onActivated: Browser.newWindow(false) }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: Browser.newWindow(true) }
    Shortcut { sequences: ["Ctrl+W", "Ctrl+F4"]; onActivated: window.tabs.close(window.tabs.currentId) }
    Shortcut { sequence: "Ctrl+Shift+T"; onActivated: window.tabs.reopenClosed() }
    Shortcut { sequences: ["Ctrl+Tab", "Ctrl+PgDown"]; onActivated: window.selectByOffset(1) }
    Shortcut { sequences: ["Ctrl+Shift+Tab", "Ctrl+PgUp"]; onActivated: window.selectByOffset(-1) }
    Instantiator {   // Ctrl+1 … Ctrl+8: that tab; Ctrl+9: the last tab
        model: 9
        delegate: Shortcut {
            required property int index
            sequence: "Ctrl+" + (index + 1)
            onActivated: window.tabs.currentId = window.tabs.idAt(index === 8 ? window.tabs.count - 1 : index)
        }
    }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: sidebar.toggle() }
    Shortcut { sequence: "Ctrl+Shift+A"; onActivated: sidebar.focusSearch() }
    Shortcut { sequences: ["Ctrl+L", "Alt+D", "F6"]; onActivated: toolbar.focusAddress() }
    Shortcut { sequence: "Ctrl+D"; onActivated: toolbar.toggleBookmark() }
    Shortcut { sequence: "Ctrl+H"; onActivated: window.showPanel("history") }
    Shortcut { sequence: "Ctrl+Shift+O"; onActivated: window.showPanel("bookmarks") }
    Shortcut { sequence: "Ctrl+J"; onActivated: window.showPanel("downloads") }
    Shortcut { sequence: "Ctrl+,"; onActivated: window.showPanel("settings") }
    Shortcut { sequences: ["Ctrl+F", "F3"]; enabled: window.view !== null; onActivated: findBar.open() }
    Shortcut { sequence: "Ctrl+P"; enabled: window.view !== null; onActivated: pdfDialog.open() }
    Shortcut { sequences: ["Alt+Left", "Ctrl+["]; onActivated: if (window.view) window.view.goBack() }
    Shortcut { sequences: ["Alt+Right", "Ctrl+]"]; onActivated: if (window.view) window.view.goForward() }
    Shortcut { sequences: ["F5", "Ctrl+R"]; onActivated: if (window.view) window.view.reload() }
    Shortcut { sequences: ["Ctrl+F5", "Shift+F5", "Ctrl+Shift+R"]; onActivated: if (window.view) window.view.reloadAndBypassCache() }
    Shortcut { sequence: "Alt+Home"; onActivated: if (window.view) window.view.url = Browser.homeUrl }
    Shortcut {
        sequence: "Esc"
        enabled: window.panel !== "" || (window.view !== null && window.view.loading)
        onActivated: window.panel !== "" ? window.panel = "" : window.view.stop()
    }
    Shortcut { sequences: ["Ctrl+=", "Ctrl++"]; onActivated: window.zoom(1) }
    Shortcut { sequence: "Ctrl+-"; onActivated: window.zoom(-1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: window.zoom(0) }
    Shortcut { sequence: "F11"; onActivated: window.toggleFullScreen() }
    Shortcut { sequences: ["F12", "Ctrl+Shift+I"]; enabled: window.view !== null; onActivated: window.openDevTools() }
}
