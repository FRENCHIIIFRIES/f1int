import QtQuick
import QtWebEngine
import f1int

// UI walk-through of bookmarks, history, find, panels, light theme and tab sleeping.
// Run with tools\ui-test.ps1 tests\ui\features.qml (uses a separate test profile).
Item {
    id: test
    property var win
    property int step: 0
    function say(text) { console.warn("SHOT " + text) }
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }

    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            const tabs = w.tabs
            switch (test.step++) {
            case 0: break   // let the first page load
            case 1:
                w.toolbarItem.toggleBookmark()
                test.check(Browser.library.isBookmarked(w.view.url), "star bookmarks the page")
                test.check(Browser.library.history().length > 0, "visit recorded in history")
                break
            case 2: test.say("starred"); break
            case 3: w.panel = "bookmarks"; break
            case 4: test.say("bookmarks"); break
            case 5: w.panel = "history"; break
            case 6: test.say("history"); break
            case 7: w.panel = "settings"; break
            case 8: test.say("settings"); break
            case 9: Browser.setSetting("appearance/theme", "light"); break
            case 10: test.say("settings-light"); break
            case 11: Browser.setSetting("appearance/theme", "dark"); w.panel = "memory"; break
            case 12: test.say("memory"); break
            case 13: w.panel = ""; w.newTab("https://example.com", true); break
            case 14: tabs.currentId = tabs.idAt(1); break                  // open it so it gets a page
            case 15: if (w.pages[tabs.idAt(1)].loading) test.step--; break   // wait until it has loaded
            case 16: {
                tabs.currentId = tabs.idAt(0)
                const page = w.pages[tabs.idAt(1)]
                console.warn("before sleep: state=" + page.lifecycleState + " recommended=" + page.recommendedState
                             + " audible=" + page.recentlyAudible + " visible=" + page.visible)
                page.hasUnsavedInput(edited => console.warn("unsaved input: " + edited))
                w.sleepIdleTabs(true)
                break
            }
            case 17: {
                const page = w.pages[tabs.idAt(1)]
                console.warn("after sleep: state=" + page.lifecycleState + " recommended=" + page.recommendedState)
                test.check(page && page.lifecycleState === WebEngineView.LifecycleState.Discarded, "background tab put to sleep")
                test.check(tabs.tab(tabs.idAt(1)).asleep, "sleeping tab shown dimmed")
                break
            }
            case 18: w.findBarItem.open(); break
            case 19: test.say("find"); break
            case 20:
                console.warn("DONE tabs=" + tabs.count)
                running = false
                break
            }
        }
    }
}
