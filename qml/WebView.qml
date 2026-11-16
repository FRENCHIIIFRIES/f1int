import QtQuick
import QtWebEngine
import f1int

// The web page of one tab. Created the first time a tab is opened (not before,
// to save RAM) and destroyed when the tab closes. Reports its state to the tab list.
WebEngineView {
    id: view
    required property int tabId
    signal openRequested(var request)   // a link wants a new tab or window

    profile: Browser.profile
    backgroundColor: Theme.bg            // blank tabs are black, not white
    visible: tabId === Browser.tabs.currentId

    onTitleChanged: Browser.tabs.update(tabId, { title: title })
    onUrlChanged: Browser.tabs.update(tabId, { url: url })
    onIconChanged: Browser.tabs.update(tabId, { icon: icon })
    onLoadingChanged: Browser.tabs.update(tabId, { loading: loading })
    onRecentlyAudibleChanged: Browser.tabs.update(tabId, { audible: recentlyAudible })
    onLifecycleStateChanged: Browser.tabs.update(tabId, { asleep: lifecycleState !== WebEngineView.LifecycleState.Active })
    onNewWindowRequested: (request) => openRequested(request)
}
