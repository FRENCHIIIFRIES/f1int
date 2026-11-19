import QtQuick
import QtWebEngine
import f1int

// The web page of one tab. Created the first time a tab is opened (not before,
// to save RAM) and destroyed when the tab closes. Reports its state to the tab list.
WebEngineView {
    id: view
    required property int tabId
    property TabModel tabs
    property bool incognito: false
    property bool hasLoginForm: false      // the page shows a password box
    property string pendingUsername: ""    // email typed on the first page of a two-step login
    signal openRequested(var request)      // a link wants a new tab or window
    signal loginSubmitted(string username, string password)
    signal loginBoxFocused(var rect)       // a login box got focus: { x, y, w, h } in page pixels (or null)
    signal newPasswordFocused()            // sign-up box: could suggest a strong password
    signal pageLoaded()
    property bool poppedOut: false         // shown in the small pop-out video window
    property bool readerOn: false          // reading view is showing
    signal readerMissing()                 // asked for reading view, but there's no article here

    // Asks the page whether the user typed into a form that wasn't sent yet. The check runs
    // in a separate script "world" the page itself can't see or tamper with.
    function hasUnsavedInput(callback) {
        runJavaScript("window.__f1intEdited === true", WebEngineScript.ApplicationWorld, (edited) => callback(edited === true))
    }
    // ---- password helper (see resources/scripts/passwords.js) ----
    function checkLoginForm() {
        runJavaScript("window.__f1intHasLogin ? __f1intHasLogin() : false", WebEngineScript.ApplicationWorld,
                      (found) => hasLoginForm = found === true)
    }
    function fillLogin(username, password) {
        runJavaScript("window.__f1intFill && __f1intFill(" + JSON.stringify(username) + "," + JSON.stringify(password) + ")",
                      WebEngineScript.ApplicationWorld)
    }
    function fillNewPassword(password) {
        runJavaScript("window.__f1intFillNew && __f1intFillNew(" + JSON.stringify(password) + ")", WebEngineScript.ApplicationWorld)
    }

    // ---- media controls and pop-out video (resources/scripts/media.js) ----
    // action: "status" | "toggle" | "pip-on" | "pip-off"; callback gets {playing, title, artist, video} or null.
    function media(action, callback) {
        runJavaScript(Browser.script("media") + "(" + JSON.stringify(action) + ")", WebEngineScript.ApplicationWorld,
                      (info) => { if (callback) callback(info || null) })
    }
    // ---- reading view (resources/scripts/reader.js) ----
    function reader(on) {
        const look = { size: Number(Browser.setting("reader/size", 19)), font: String(Browser.setting("reader/font", "sans")),
                       width: Number(Browser.setting("reader/width", 680)) }
        for (const k of ["bg", "fg", "dim", "accent", "line", "field"]) look[k] = css(Theme[k])
        runJavaScript(Browser.script("reader") + "(" + on + "," + JSON.stringify(look) + ")", WebEngineScript.ApplicationWorld,
                      (result) => { readerOn = result === "on"; if (result === "none") readerMissing() })
    }
    function css(c) { return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + c.a.toFixed(3) + ")" }

    // Empty tabs are see-through (the new tab page shows the glass); pages get the theme colour.
    backgroundColor: url.toString() === "" ? "transparent" : Theme.bg
    visible: poppedOut || tabId === tabs.currentId

    onTitleChanged: tabs.update(tabId, { title: title })
    onUrlChanged: { tabs.update(tabId, { url: url }); hasLoginForm = false; readerOn = false }
    onIconChanged: {
        tabs.update(tabId, { icon: icon })
        if (!incognito && icon.toString() !== "") Browser.favicons.pageIcon(url, icon)   // kept for bookmarks
    }
    onRecentlyAudibleChanged: tabs.update(tabId, { audible: recentlyAudible })
    onLifecycleStateChanged: tabs.update(tabId, { asleep: lifecycleState !== WebEngineView.LifecycleState.Active })
    onNewWindowRequested: (request) => openRequested(request)
    signal notificationsAsked(var permission)   // a site wants to show notifications
    onPermissionRequested: (permission) => {
        if (permission.permissionType === WebEnginePermission.PermissionType.Notifications) notificationsAsked(permission)
        else permission.deny()   // camera, microphone, location...: not supported yet
    }
    onLoadingChanged: (info) => {
        tabs.update(tabId, { loading: loading })
        if (!loading && info.status === WebEngineLoadingInfo.LoadSucceededStatus) {
            if (!incognito) Browser.library.addVisit(url, title)   // history (never in incognito)
            checkLoginForm()
            pageLoaded()
        }
    }
    // Messages from the password helper. Only ones starting with the secret prefix count;
    // everything else (the page's own console output) is ignored and never logged.
    onJavaScriptConsoleMessage: (level, message) => {
        const prefix = Browser.passwordMessagePrefix
        if (!message.startsWith(prefix)) return
        const rest = message.substring(prefix.length)
        const kind = rest.substring(0, rest.indexOf(":"))
        let data
        try { data = JSON.parse(rest.substring(kind.length + 1)) } catch (e) { return }
        if (kind === "login") loginSubmitted(data.username || pendingUsername, data.password)
        else if (kind === "username") pendingUsername = data.username
        else if (kind === "passwordfocus") { hasLoginForm = true; loginBoxFocused(data.rect || null) }
        else if (kind === "newpassword") { hasLoginForm = true; newPasswordFocused() }
        else if (kind === "reader") readerOn = data.on === true
        else if (kind === "readerlook") {   // A− / A+ / Serif-Sans in the reading view: save, then redraw
            const size = Number(Browser.setting("reader/size", 19))
            if (data.change === "smaller") Browser.setSetting("reader/size", Math.max(14, size - 1))
            else if (data.change === "bigger") Browser.setSetting("reader/size", Math.min(28, size + 1))
            else if (data.change === "font") Browser.setSetting("reader/font", Browser.setting("reader/font", "sans") === "serif" ? "sans" : "serif")
            reader(true)   // shortcut: redrawing scrolls back to the top; keep the position if anyone minds
        }
    }
}
