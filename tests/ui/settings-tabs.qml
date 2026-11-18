import QtQuick
import f1int

// Settings must get out of the way: a new tab, a tab switch or a search shows the page.
Item {
    id: test
    property var win
    property int step: 0
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    Timer {
        interval: 1200
        repeat: true
        running: true
        onTriggered: {
            const w = test.win, tabs = w.tabs
            switch (test.step++) {
            case 0: w.panel = "settings"; break
            case 1: w.openNewTab(); break
            case 2: test.check(w.panel === "", "a new tab closes settings")
                    test.check(w.view && w.view.visible, "the new tab's page shows"); w.panel = "settings"; break
            case 3: tabs.currentId = tabs.idAt(0); break
            case 4: test.check(w.panel === "", "switching tabs closes settings")
                    test.check(w.view === w.pages[tabs.idAt(0)], "the tab you picked is the one shown")
                    tabs.currentId = tabs.idAt(1); break
            case 5: test.check(w.view === w.pages[tabs.idAt(1)] && w.view.visible, "switching again works"); w.panel = "settings"; break
            case 6: w.toolbarItem.go(Browser.urlFromInput("f1int test search")); break
            case 7: test.check(w.panel === "", "searching closes settings")
                    test.check(w.view.url.toString().indexOf("google.com/search") > 0, "the search went to Google (" + w.view.url + ")"); break
            case 8: w.panel = "customise"; tabs.currentId = tabs.idAt(0); break
            case 9: test.check(w.panel === "customise", "side panels stay open while switching"); console.warn("DONE"); running = false; break
            }
        }
    }
}
