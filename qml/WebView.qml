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
    signal loginBoxFocused()               // could fill a saved login now
    signal newPasswordFocused()            // sign-up box: could suggest a strong password
    signal pageLoaded()

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

    // Empty tabs are see-through (the new tab page shows the glass); pages get the theme colour.
    backgroundColor: url.toString() === "" ? "transparent" : Theme.bg
    visible: tabId === tabs.currentId

    onTitleChanged: tabs.update(tabId, { title: title })
    onUrlChanged: { tabs.update(tabId, { url: url }); hasLoginForm = false }
    onIconChanged: tabs.update(tabId, { icon: icon })
    onRecentlyAudibleChanged: tabs.update(tabId, { audible: recentlyAudible })
    onLifecycleStateChanged: tabs.update(tabId, { asleep: lifecycleState !== WebEngineView.LifecycleState.Active })
    onNewWindowRequested: (request) => openRequested(request)
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
        else if (kind === "passwordfocus") { hasLoginForm = true; loginBoxFocused() }
        else if (kind === "newpassword") { hasLoginForm = true; newPasswordFocused() }
    }
}
