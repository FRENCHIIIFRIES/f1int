import QtQuick
import QtWebEngine
import f1int

// Tab sleeping, one step per tick (finds where things stop if they ever do).
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
            case 0: w.newTab("https://example.com", true); break
            case 1: tabs.currentId = tabs.idAt(1); console.warn("T opened"); break
            case 2: if (w.pages[tabs.idAt(1)].loading) test.step--; else console.warn("T loaded"); break
            case 3: tabs.currentId = tabs.idAt(0); console.warn("T switched back"); break
            case 4: w.pages[tabs.idAt(1)].hasUnsavedInput(e => console.warn("T unsaved=" + e)); console.warn("T asked"); break
            case 5: w.sleepIdleTabs(true); console.warn("T slept"); break
            case 6: break
            case 7: { const page = w.pages[tabs.idAt(1)]
                      test.check(page.lifecycleState !== WebEngineView.LifecycleState.Active, "background tab sleeps (state " + page.lifecycleState + ")")
                      test.check(tabs.tab(tabs.idAt(1)).asleep, "sleeping tab shown dimmed"); break }
            case 8: console.warn("DONE"); running = false; break
            }
        }
    }
}
