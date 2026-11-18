import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Effects
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
    color: Theme.chrome   // the frame around the page (see-through only with frosted glass on)
    // The profile's name shows in the title once there's more than one profile.
    title: (view && view.title ? view.title : qsTr("New tab")) + (incognito ? " – f1int Incognito"
           : Browser.profiles.list.length > 1 ? " – " + Browser.profiles.currentName + " – f1int" : " – f1int")
    palette.toolTipBase: Theme.surface
    palette.toolTipText: Theme.fg

    // ---------- tabs and pages ----------
    function setting(key, fallback) { void Browser.settingsRevision; return Browser.setting(key, fallback) }
    // New tabs: f1int's own page (default), a blank page, the home page, or any address.
    function newTabUrl() {
        const mode = setting("newtab/mode", "home")   // default: google.com (the home page)
        return mode === "home" ? Browser.homeUrl : mode === "custom" ? Browser.urlFromInput(setting("newtab/url", "")) : "about:blank"
    }
    readonly property bool showNewTabPage: view !== null && setting("newtab/mode", "home") === "f1int"
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
    function showSettings(category) {   // open settings at a category (after it has loaded)
        panel = "settings"
        Qt.callLater(() => { const p = pageArea.children.find(c => c.item && c.item.category !== undefined); if (p) p.item.category = category })
    }

    // ---------- passwords ----------
    property var savePrompt: null       // { url, username, password, kind } after a login was sent
    property var suggestion: null       // { page, password } for a sign-up box
    property var pendingAction: null    // runs once the vault is unlocked
    function host(url) { return url.toString().replace(/^https?:\/\/(www\.)?/, "").split("/")[0] }
    // Run `action` with the vault unlocked: asks Windows Hello / Touch ID, or opens the
    // Passwords panel for the master password (or to create the vault the first time).
    function withUnlocked(action) {
        const v = Browser.passwords
        if (v.state === "unlocked") return action()
        pendingAction = action
        if (v.state === "locked" && v.deviceUnlock) Browser.askDevice(window, "unlock")
        else panel = "passwords"
    }
    function offerSave(page, username, password) {
        if (incognito || password === "" || !setting("passwords/offer", true)) return
        if (String(setting("passwords/never", "")).split("\n").indexOf(host(page.url)) >= 0) return
        const v = Browser.passwords
        const kind = v.state === "unlocked" ? v.saveKind(page.url, username, password) : "new"
        if (kind !== "same") savePrompt = { url: page.url, username: username, password: password, kind: kind }
    }
    function savePassword() {
        const s = savePrompt
        savePrompt = null
        withUnlocked(() => Browser.passwords.save(s.url, s.username, s.password))
    }
    function neverSave() {
        const list = String(setting("passwords/never", "")).split("\n").filter(x => x)
        list.push(host(savePrompt.url))
        Browser.setSetting("passwords/never", list.join("\n"))
        savePrompt = null
    }
    // Fill a saved login when there's exactly one for this site (more: pick from the key button).
    function autofill(page) {
        if (!setting("passwords/autofill", true) || Browser.passwords.state !== "unlocked") return
        const logins = Browser.passwords.loginsFor(page.url)
        if (logins.length === 1) page.fillLogin(logins[0].username, Browser.passwords.password(logins[0].id))
    }
    function fillAs(id) {
        withUnlocked(() => {
            const login = Browser.passwords.loginsFor(view.url).find(l => l.id === id)
            if (login) view.fillLogin(login.username, Browser.passwords.password(id))
        })
    }
    function suggestPassword(page) {
        if (setting("passwords/generator", true)) suggestion = { page: page, password: Browser.passwords.generate(20) }
    }
    Connections {
        target: Browser.passwords
        function onChanged() {
            if (Browser.passwords.state === "unlocked" && window.pendingAction) {
                const action = window.pendingAction
                window.pendingAction = null
                action()
            }
        }
    }
    Connections {
        target: Browser
        function onDeviceAuthFinished(purpose, ok, error) {
            if (purpose === "unlock" && !ok && window.pendingAction) window.panel = "passwords"   // fall back to the master password
        }
    }

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
            if (id === tabs.currentId || page.recentlyAudible || page.poppedOut) continue
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
            // Settings covers the whole page area: switching or opening a tab puts the page back.
            if (window.panel === "settings") window.panel = ""
            if (id < 0) { window.view = null; return }
            const page = window.pageFor(id)
            page.lifecycleState = WebEngineView.LifecycleState.Active   // wake it if it was asleep
            window.lastActive[id] = now
            window.view = page
            page.forceActiveFocus()
        }
        function onTabClosed(id) {
            const page = window.pages[id]
            if (id === window.pipTabId) window.popIn()
            if (page) { delete window.pages[id]; page.destroy() }   // frees the page's memory
            if (id === window.mediaTabId) { window.mediaTabId = -1; window.mediaInfo = null }
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
            if (window.setting("downloads/ask", false)) {
                // Ask where to save: only the window whose page started it shows the dialog.
                const mine = download.view ? Object.values(window.pages).indexOf(download.view) >= 0 : window.active
                if (!mine) return
                saveAsDialog.download = download
                saveAsDialog.currentFile = "file:///" + download.downloadDirectory + "/" + download.downloadFileName
                saveAsDialog.open()
                return
            }
            download.accept()
            window.downloads = [download].concat(window.downloads)
            window.panel = "downloads"
        }
    }

    FileDialog {
        id: saveAsDialog
        property var download: null
        fileMode: FileDialog.SaveFile
        onAccepted: {
            const path = Browser.localPath(selectedFile)
            download.downloadDirectory = path.substring(0, path.lastIndexOf("/"))
            download.downloadFileName = path.substring(path.lastIndexOf("/") + 1)
            download.accept()
            window.downloads = [download].concat(window.downloads)
            window.panel = "downloads"
        }
        onRejected: download.cancel()
    }

    onClosing: {
        Browser.unregisterWindow(tabs)
        for (const key in pages) pages[key].destroy()   // free the pages; the window object itself stays tiny
        pages = {}
    }

    // Frosted glass behind the window (Windows 11), redone when light/dark changes.
    function applyGlass() { if (Theme.glass) Browser.applyBackdrop(window, Theme.dark) }
    Connections { target: Theme; function onDarkChanged() { window.applyGlass() } function onGlassChanged() { window.applyGlass() } }

    Component.onCompleted: {
        applyGlass()
        applyFrame()
        const downloadsTo = String(setting("downloads/path", ""))
        if (downloadsTo !== "" && !incognito) profile.downloadPath = downloadsTo
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
        // The password helper (notices logins, fills saved ones), also in the separate world.
        if (profile.userScripts.find("f1int-passwords").length === 0) {
            const p = WebEngine.script()
            p.name = "f1int-passwords"
            p.sourceCode = Browser.passwordScript
            p.injectionPoint = WebEngineScript.DocumentReady
            p.worldId = WebEngineScript.ApplicationWorld
            p.runsOnSubFrames = false
            profile.userScripts.insert(p)
        }

        const restored = Browser.registerWindow(tabs, incognito)   // reopens last session's tabs
        const start = Browser.takeStartUrls()
        for (let i = 0; i < start.urls.length; ++i)
            newTab(start.urls[i], i > 0 || restored)
        if (!restored && start.urls.length === 0)
            newTab(start.first ? Browser.homeUrl : newTabUrl())

        // UI test scripts (tests/ui/*.qml) run only when F1INT_UI_TEST names one.
        if (Browser.uiTestScript.toString() !== "") {
            const test = Qt.createComponent(Browser.uiTestScript)
            if (test.status === Component.Error) console.warn("UI test failed to load: " + test.errorString())
            else if (!test.createObject(window, { win: window })) console.warn("UI test couldn't start: " + test.errorString())
        }
    }
    // ---------- media: the "now playing" card in the tab bar and the pop-out video ----------
    property int mediaTabId: -1        // the tab that played sound most recently
    property var mediaInfo: null       // { playing, title, artist, video } from that page
    property int pipTabId: -1          // the tab shown in the small video window
    readonly property var mediaCard: {
        if (mediaTabId < 0 || mediaInfo === null) return null
        const tab = tabs.tab(mediaTabId)
        return Object.assign({ tabId: mediaTabId, icon: tab.icon, tabTitle: tab.title, muted: tab.muted === true,
                               poppedOut: pipTabId === mediaTabId }, mediaInfo)
    }
    function refreshMedia() {
        const page = pages[mediaTabId]
        if (!page || page.lifecycleState === WebEngineView.LifecycleState.Discarded) { mediaTabId = -1; mediaInfo = null; return }
        if (page.lifecycleState !== WebEngineView.LifecycleState.Active) return   // asleep: keep what we know
        const id = mediaTabId
        page.media("status", (info) => { if (id !== mediaTabId) return; mediaInfo = info; if (info === null) mediaTabId = -1 })
    }
    function mediaAction(action) {
        const page = pages[mediaTabId]
        if (!page) return
        if (action === "focus") { tabs.currentId = mediaTabId; return }
        if (action === "mute") { setMuted(mediaTabId, !page.audioMuted); mediaInfo = Object.assign({}, mediaInfo); return }
        if (action === "pip") { pipTabId === mediaTabId ? popIn() : popOut(mediaTabId); return }
        page.lifecycleState = WebEngineView.LifecycleState.Active
        page.media(action, (info) => mediaInfo = info)
    }
    Timer {
        interval: 2000
        repeat: true
        running: window.mediaTabId >= 0 && Qt.application.state === Qt.ApplicationActive
        onTriggered: window.refreshMedia()
    }
    // Pop-out video: the tab's page moves into a small window that stays on top, and the
    // video is made to fill it. Qt WebEngine has no picture-in-picture of its own.
    function popOut(id) {
        const page = pages[id]
        if (!page) return
        if (pipTabId >= 0) popIn()
        page.lifecycleState = WebEngineView.LifecycleState.Active
        pipTabId = id
        page.media("pip-on")
        page.poppedOut = true
        page.parent = pipWindow.contentItem
        pipWindow.show()
    }
    function popIn() {
        const page = pages[pipTabId]
        pipTabId = -1
        if (page) { page.media("pip-off"); page.poppedOut = false; page.parent = pageArea }
        if (pipWindow.visible) pipWindow.hide()
    }
    Window {
        id: pipWindow
        width: 480
        height: 270
        minimumWidth: 240
        minimumHeight: 135
        x: Screen.desktopAvailableWidth - width - 24
        y: Screen.desktopAvailableHeight - height - 24
        flags: Qt.Window | Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
        color: "black"
        title: qsTr("f1int video")
        onClosing: window.popIn()
        // Controls appear while the mouse is over the window.
        Item {
            anchors.fill: parent
            z: 10
            HoverHandler { id: pipHover }
            Rectangle {
                width: parent.width
                height: 40
                opacity: pipHover.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                gradient: Gradient { GradientStop { position: 0; color: "#b0000000" } GradientStop { position: 1; color: "#00000000" } }
                MouseArea { anchors.fill: parent; onPressed: pipWindow.startSystemMove() }   // drag to move
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    IconButton {
                        iconName: window.mediaCard && window.mediaCard.playing ? "pause" : "play"
                        iconColor: "white"
                        tip: qsTr("Play or pause")
                        onClicked: window.mediaAction("toggle")
                    }
                    IconButton {
                        iconName: "pip"
                        iconColor: "white"
                        tip: qsTr("Back to the tab")
                        onClicked: { const id = window.pipTabId; window.popIn(); window.tabs.currentId = id; window.raise() }
                    }
                    IconButton { iconName: "close"; iconColor: "white"; tip: qsTr("Close"); onClicked: window.popIn() }
                }
            }
            MouseArea {   // resize from the bottom-right corner
                width: 18
                height: 18
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                cursorShape: Qt.SizeFDiagCursor
                onPressed: pipWindow.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
            }
        }
    }

    // A new version: say so once, quietly.
    Connections {
        target: Browser.updater
        function onChanged() {
            if (Browser.updater.state === "available" && window.active && !window.updateNoted) {
                window.updateNoted = true
                window.flash(qsTr("f1int %1 is out. Settings > Advanced > Updates").arg(Browser.updater.latest))
            }
        }
    }
    property bool updateNoted: false

    ProfileMenu { id: profileMenu; onManageRequested: window.showSettings("general"); onAccountRequested: window.showSettings("account") }

    // A short message at the bottom of the page (e.g. "No article found").
    function flash(text) { flashText.text = text; flashBox.opacity = 1; flashTimer.restart() }
    Timer { id: flashTimer; interval: 2600; onTriggered: flashBox.opacity = 0 }

    // ---------- bookmarks bar (under the address bar) ----------
    readonly property int bookmarksBarHeight: Theme.showBookmarksBar && !incognito && !fullScreen ? 32 : 0
    BookmarksBar {
        parent: Theme.addressPlace === "window" ? windowBar : topBar
        visible: window.bookmarksBarHeight > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        height: 31
        onOpen: (url, background) => background ? window.newTab(url, true) : (window.view ? window.view.url = url : window.newTab(url))
    }
    Shortcut { sequence: "Ctrl+Shift+B"; onActivated: Browser.setSetting("layout/bookmarksBar", !Theme.showBookmarksBar) }

    // The Windows title bar takes the tab column's colour, so the window reads as one piece.
    function applyFrame() { Browser.applyFrameColors(window, Theme.sidebar, Theme.fg, Theme.dark) }
    Connections { target: Theme; function onSidebarChanged() { window.applyFrame() } }

    // First run: the welcome intro over everything (not in incognito or UI tests).
    property bool showWelcome: !incognito && Browser.uiTestScript.toString() === "" && !Browser.setting("welcome/done", false)
    Loader {
        anchors.fill: parent
        z: 1000
        active: window.showWelcome
        sourceComponent: Welcome { onFinished: window.showWelcome = false }
        onLoaded: item.forceActiveFocus()
    }

    // For UI test scripts: reach the menus and panels by name.
    property alias sidebarItem: sidebar
    property alias pageAreaItem: pageArea
    property alias tabMenuItem: tabMenu
    property alias groupPopupItem: groupPopup
    property alias mainMenuItem: mainMenu
    property alias toolbarItem: toolbar
    property alias findBarItem: findBar

    Component {
        id: pageComponent
        WebView {
            id: webPage
            anchors.fill: parent
            onOpenRequested: (request) => window.handleOpen(request, tabId)
            onLinkHovered: (url) => window.hoveredLink = url.toString()
            onLoginSubmitted: (username, password) => window.offerSave(webPage, username, password)
            onPageLoaded: window.autofill(webPage)
            onLoginBoxFocused: window.autofill(webPage)
            onNewPasswordFocused: window.suggestPassword(webPage)
            onRecentlyAudibleChanged: if (recentlyAudible) { window.mediaTabId = tabId; window.refreshMedia() }
            onReaderMissing: window.flash(qsTr("No article found on this page"))
            onFullScreenRequested: (request) => {
                request.accept()
                request.toggleOn ? window.showFullScreen() : window.showNormal()
            }
        }
    }

    // ---------- layout ----------
    // The window's background (Settings > Appearance > Backgrounds): a colour, a gradient,
    // a picture or a pattern. The tab column and toolbar can be see-through over it.
    Fill {
        z: -10
        anchors.fill: parent
        spec: Theme.windowFill
        base: Theme.chrome
    }
    // ---- The address bar's own row across the top of the window (the default layout) ----
    Item {
        id: windowBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.addressPlace === "window" && !window.fullScreen ? 46 + window.bookmarksBarHeight : 0
        Fill { anchors.fill: parent; visible: parent.height > 0; spec: Theme.toolbarFill; base: Theme.toolbar }
        Rectangle {   // a thin line separates the bar from the tabs and the page below
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.line
            visible: parent.height > 0
        }
    }

    TabSidebar {
        id: sidebar
        tabs: window.tabs
        media: window.mediaCard
        onMediaAction: (action) => window.mediaAction(action)
        z: 2   // when collapsed it floats over the page while hovered
        visible: !window.fullScreen
        anchors.top: windowBar.bottom   // below the address bar when it runs across the window
        anchors.bottom: parent.bottom
        // Left or right side (Settings > Appearance > Layout).
        x: Theme.tabsOnRight ? window.width - width : 0
        hasToolbar: Theme.addressInSidebar
        onNewTabRequested: window.openNewTab()
        onTabMenuRequested: (id) => tabMenu.openFor(id)
        onGroupMenuRequested: (id) => groupMenu.openFor(sidebar.groupInfo(id))
        onMuteToggled: (id) => window.setMuted(id, !window.tabs.tab(id).muted)
        onPanelRequested: (name) => window.showPanel(name)
    }
    // The toolbar is above the page when it's set to "on top", or while the tab bar is collapsed.
    readonly property bool toolbarOnTop: Theme.addressPlace === "page" || (Theme.addressInSidebar && sidebar.collapsed)

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: windowBar.bottom
        anchors.bottom: parent.bottom
        // Room for the tab bar on its side, and a gap around the page card (none in full screen).
        anchors.leftMargin: window.fullScreen || Theme.tabsOnRight ? 0 : sidebar.reservedWidth
        anchors.rightMargin: window.fullScreen || !Theme.tabsOnRight ? 0 : sidebar.reservedWidth
        spacing: 0

        // The toolbar sits here, above the page, only while the tab bar is collapsed.
        Rectangle {
            id: topBar
            visible: (window.toolbarOnTop || window.bookmarksBarHeight > 0) && Theme.addressPlace !== "window" && !window.fullScreen
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? (window.toolbarOnTop ? 46 : 0) + window.bookmarksBarHeight : 0
            color: "transparent"
            Fill { anchors.fill: parent; spec: Theme.toolbarFill; base: Theme.toolbar }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
        }

        // ---- The page card: rounded corners, solid background, sits on the glass ----
        Item {
            id: card
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: window.fullScreen ? 0 : Theme.inset
            // Over a picture or gradient the corners must be cut from the page itself (costs a
            // little GPU time); over a plain colour, painted caps do it for free (below).
            layer.enabled: Theme.hasWallpaper && !window.fullScreen && Theme.inset > 0
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cardMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
            Rectangle {   // background; see-through for the new tab page so the glass shows
                anchors.fill: parent
                color: window.showNewTabPage ? "transparent" : Theme.bg
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0
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
                            font.pixelSize: Theme.px(11)
                            elide: Text.ElideMiddle
                        }
                    }
                    Rectangle {
                        id: flashBox
                        z: 9
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 24
                        width: flashText.implicitWidth + 32
                        height: 36
                        radius: 18
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.line
                        opacity: 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                        Text { id: flashText; anchors.centerIn: parent; color: Theme.fg; font.pixelSize: Theme.px(13) }
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
                            font.family: Theme.numberFont
                            font.pixelSize: Theme.px(15)
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

                    // Settings: a full page over the page area.
                    Loader {
                        z: 7
                        anchors.fill: parent
                        active: window.panel === "settings"
                        sourceComponent: SettingsPage {
                            focus: true
                            onCloseRequested: window.panel = ""
                            onOpenPanel: (name) => window.panel = name
                            onWelcomeRequested: { window.panel = ""; window.showWelcome = true }
                            onOpenUrl: (u) => { window.panel = ""; window.newTab(u) }
                            onNewTabPageRequested: {
                                window.panel = ""
                                Browser.setSetting("newtab/mode", "f1int")
                                window.openNewTab()
                                Qt.callLater(() => { if (newTabPage.item) newTabPage.item.openCustomise() })
                            }
                        }
                        onLoaded: item.forceActiveFocus()
                    }
                    // Side panel on the right: bookmarks / history / downloads, customise, memory, passwords.
                    Loader {
                        z: 6
                        active: window.panel !== "" && window.panel !== "settings"
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.min(400, parent.width - 40)
                        sourceComponent: window.panel === "customise" ? settingsPanel
                                       : window.panel === "memory" ? memoryPanel
                                       : window.panel === "passwords" ? passwordsPanel : libraryPanel
                    }

                    // "Save password?" and "Use a strong password?" cards, top right under the toolbar.
                    Column {
                        z: 7
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8
                        width: 330

                        PromptCard {
                            visible: window.savePrompt !== null
                            title: window.savePrompt === null ? "" : window.savePrompt.kind === "update"
                                   ? qsTr("Update the password for %1?").arg(window.host(window.savePrompt.url))
                                   : qsTr("Save the password for %1?").arg(window.host(window.savePrompt.url))
                            detail: window.savePrompt === null ? "" : (window.savePrompt.username || qsTr("No username"))
                            dots: 10
                            Ui.Pill { text: qsTr("Never here"); onClicked: window.neverSave() }
                            Ui.Pill { text: qsTr("Not now"); onClicked: window.savePrompt = null }
                            Ui.Pill { primary: true; text: window.savePrompt && window.savePrompt.kind === "update" ? qsTr("Update") : qsTr("Save"); onClicked: window.savePassword() }
                        }
                        PromptCard {
                            visible: window.suggestion !== null
                            title: qsTr("Use a strong password?")
                            detail: window.suggestion ? window.suggestion.password : ""
                            mono: true
                            IconButton { iconName: "dice"; tip: qsTr("Another one"); onClicked: window.suggestion = { page: window.suggestion.page, password: Browser.passwords.generate(20) } }
                            Ui.Pill { text: qsTr("No thanks"); onClicked: window.suggestion = null }
                            Ui.Pill {
                                primary: true
                                text: qsTr("Use it")
                                onClicked: { window.suggestion.page.fillNewPassword(window.suggestion.password); window.suggestion = null }
                            }
                        }
                    }
                }
            }

            // Loading progress: a thin accent line along the card's top edge.
            Rectangle {
                z: 8
                width: window.view && window.view.loading ? parent.width * window.view.loadProgress / 100 : 0
                height: 2
                color: Theme.accent
                visible: width > 0
                Behavior on width { NumberAnimation { duration: Theme.anim } }
            }
            // Rounded corners: frame-coloured caps drawn over the page's square corners
            // (much cheaper than masking a live web page), plus a hairline edge.
            Repeater {
                model: window.fullScreen || Theme.inset === 0 || Theme.hasWallpaper ? 0 : 4
                Canvas {
                    required property int index
                    readonly property int r: Theme.cardRadius
                    z: 20
                    width: r
                    height: r
                    x: index % 2 ? card.width - r : 0
                    y: index > 1 ? card.height - r : 0
                    onPaint: {   // fill the square, then cut out the circle around the card's inner corner
                        const c = getContext("2d"); c.reset()
                        c.fillStyle = Theme.chrome; c.fillRect(0, 0, r, r)
                        c.globalCompositeOperation = "destination-out"
                        c.beginPath(); c.arc(index % 2 ? 0 : r, index > 1 ? 0 : r, r, 0, 2 * Math.PI); c.fill()
                    }
                    Connections { target: Theme; function onChromeChanged() { requestPaint() } function onCardRadiusChanged() { requestPaint() } }
                }
            }
            Rectangle {
                z: 21
                anchors.fill: parent
                visible: !window.fullScreen
                radius: Theme.cardRadius
                color: "transparent"
                border.width: 1
                border.color: Theme.line
            }
        }
    }

    Rectangle {   // the page's shape, used as the mask above (not drawn)
        id: cardMask
        width: card.width
        height: card.height
        radius: Theme.cardRadius
        visible: false
        layer.enabled: Theme.hasWallpaper
    }

    // The toolbar: at the top of the tab bar (stacked), or above the page when the bar is collapsed.
    Toolbar {
        id: toolbar
        parent: Theme.addressPlace === "window" ? windowBar : window.toolbarOnTop ? topBar : sidebar.toolbarSlot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: implicitHeight
        stacked: parent === sidebar.toolbarSlot   // two rows only inside the tab bar
        visible: !window.fullScreen
        view: window.view
        incognito: window.incognito
        activeDownloads: window.activeDownloads
        onMenuRequested: (button) => mainMenu.popup(button, button.width - mainMenu.width, button.height + 4)
        onPanelRequested: (name) => window.showPanel(name)
        onNavigated: if (window.panel === "settings") window.panel = ""
        onProfileRequested: (button) => {   // (a Popup, not a Menu: placed by hand under the button)
            profileMenu.parent = button
            profileMenu.x = button.width - profileMenu.width
            profileMenu.y = button.height + 6
            profileMenu.open()
        }
        onKeyRequested: (button) => {
            keyMenu.logins = Browser.passwords.state === "unlocked" ? Browser.passwords.loginsFor(window.view.url) : []
            keyMenu.popup(button, button.width - keyMenu.width, button.height + 6)
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
    Component { id: settingsPanel; SettingsPanel { onCloseRequested: window.panel = ""; onStudioRequested: window.showSettings("appearance") } }
    Component { id: passwordsPanel; PasswordsPanel { onCloseRequested: { window.panel = ""; window.pendingAction = null } } }

    // A small card with a question and buttons (the password prompts).
    component PromptCard: Rectangle {
        id: card
        property string title
        property string detail
        property bool mono: false
        property int dots: 0          // a hidden password, drawn as dots
        default property alias buttons: buttonRow.data
        width: parent ? parent.width : 330
        height: cardColumn.implicitHeight + 28
        radius: 14
        color: Theme.surface
        border.width: 1
        border.color: Theme.line
        Column {
            id: cardColumn
            x: 16
            y: 14
            width: parent.width - 32
            spacing: 10
            Row {
                spacing: 10
                width: parent.width
                Icon { glyph: "key"; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Text { text: card.title; color: Theme.fg; font.pixelSize: Theme.px(13); wrapMode: Text.Wrap; width: parent.width - 30 }
            }
            Row {
                spacing: 12
                width: parent.width
                Text {
                    text: card.detail
                    color: card.mono ? Theme.fg : Theme.dim
                    font.family: card.mono ? "Consolas, Menlo, monospace" : ""
                    font.pixelSize: Theme.px(card.mono ? 15 : 12)
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - (card.dots > 0 ? 80 : 0))
                    anchors.verticalCenter: parent.verticalCenter
                }
                Ui.Dots { visible: card.dots > 0; count: card.dots; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                id: buttonRow
                anchors.right: parent.right
                spacing: 6
            }
        }
    }
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
        Action { text: qsTr("Passwords"); onTriggered: window.showPanel("passwords") }
        Action { text: qsTr("Reopen closed tab"); onTriggered: window.tabs.reopenClosed() }
        Separator {}
        Action { text: qsTr("Find in page"); enabled: window.view !== null; onTriggered: findBar.open() }
        Action { text: window.view && window.view.readerOn ? qsTr("Close reading view") : qsTr("Reading view"); enabled: window.view !== null; onTriggered: window.view.reader(!window.view.readerOn) }
        Action { text: qsTr("Save page as PDF"); enabled: window.view !== null; onTriggered: pdfDialog.open() }
        Action { text: qsTr("Zoom in"); onTriggered: window.zoom(1) }
        Action { text: qsTr("Zoom out"); onTriggered: window.zoom(-1) }
        Action { text: window.fullScreen ? qsTr("Exit full screen") : qsTr("Full screen"); onTriggered: window.toggleFullScreen() }
        Separator {}
        Action { text: qsTr("Memory"); onTriggered: window.showPanel("memory") }
        Action { text: qsTr("Customise"); onTriggered: window.showPanel("customise") }
        Action { text: qsTr("Settings"); onTriggered: window.showPanel("settings") }
        Action { text: qsTr("Welcome tour"); onTriggered: window.showWelcome = true }
        Action { text: qsTr("Developer tools"); enabled: window.view !== null; onTriggered: window.openDevTools() }
    }

    // The key button's menu: fill a saved login, unlock, or get a strong password.
    F1Menu {
        id: keyMenu
        property var logins: []
        Instantiator {
            model: keyMenu.logins
            delegate: Action {
                required property var modelData
                text: qsTr("Fill in as %1").arg(modelData.username || qsTr("(no username)"))
                onTriggered: window.fillAs(modelData.id)
            }
            onObjectAdded: (index, action) => keyMenu.insertAction(index, action)
            onObjectRemoved: (index, action) => keyMenu.removeAction(action)
        }
        Action {
            text: Browser.passwords.state === "none" ? qsTr("Set up passwords…") : qsTr("Unlock passwords")
            enabled: Browser.passwords.state !== "unlocked"
            onTriggered: window.withUnlocked(() => window.autofill(window.view))
        }
        Action { text: qsTr("Suggest a strong password"); onTriggered: window.suggestPassword(window.view) }
        Action { text: qsTr("Manage passwords"); onTriggered: window.panel = "passwords" }
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
            Ui.Heading { text: groupPopup.groupId >= 0 ? qsTr("Edit group") : qsTr("New group"); font.pixelSize: Theme.px(22) }
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
    Shortcut { sequence: "F9"; enabled: window.view !== null; onActivated: window.view.reader(!window.view.readerOn) }
    Shortcut { sequences: ["F12", "Ctrl+Shift+I"]; enabled: window.view !== null; onActivated: window.openDevTools() }
}
