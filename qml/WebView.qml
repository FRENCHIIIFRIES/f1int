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
    signal openRequested(var request)   // a link wants a new tab or window

    // Asks the page whether the user typed into a form that wasn't sent yet. The check runs
    // in a separate script "world" the page itself can't see or tamper with.
    function hasUnsavedInput(callback) {
        runJavaScript("window.__f1intEdited === true", WebEngineScript.ApplicationWorld, (edited) => callback(edited === true))
    }

    backgroundColor: Theme.bg            // blank tabs are black (or white in light mode)
    visible: tabId === tabs.currentId

    onTitleChanged: tabs.update(tabId, { title: title })
    onUrlChanged: tabs.update(tabId, { url: url })
    onIconChanged: tabs.update(tabId, { icon: icon })
    onRecentlyAudibleChanged: tabs.update(tabId, { audible: recentlyAudible })
    onLifecycleStateChanged: tabs.update(tabId, { asleep: lifecycleState !== WebEngineView.LifecycleState.Active })
    onNewWindowRequested: (request) => openRequested(request)
    onLoadingChanged: (info) => {
        tabs.update(tabId, { loading: loading })
        if (!loading && !incognito && info.status === WebEngineLoadingInfo.LoadSucceededStatus)
            Browser.library.addVisit(url, title)   // history (never in incognito)
    }
}
