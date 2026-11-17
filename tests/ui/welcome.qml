import QtQuick
import f1int

// Walks through the welcome intro and screenshots each page (test profile only).
Item {
    id: test
    property var win
    property int step: 0
    property var welcome: null
    function say(text) { console.warn("SHOT " + text) }
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    function find(item) {
        if (item && item.steps !== undefined && item.sparkAt !== undefined) return item
        for (let i = 0; item && i < item.children.length; ++i) { const f = find(item.children[i]); if (f) return f }
        return null
    }

    Timer {
        interval: 1700
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            switch (test.step++) {
            case 0: Browser.setSetting("appearance/glass", false); w.showWelcome = true; break
            case 1: test.welcome = test.find(w.contentItem); test.check(test.welcome !== null, "welcome opens"); break
            case 2: test.say("welcome-1"); break
            case 3: test.welcome.next(); break
            case 4: test.say("welcome-2"); break
            case 5: test.welcome.next(); break
            case 6: test.say("welcome-3"); break
            case 7: Browser.setSetting("appearance/theme", "light"); Browser.setSetting("layout/tabsSide", "right"); break
            case 8: test.say("welcome-3-light"); break
            case 9: Browser.setSetting("appearance/theme", "dark"); Browser.setSetting("layout/tabsSide", "left"); test.welcome.next(); break
            case 10: test.say("welcome-4"); break
            case 11: test.welcome.next(); break
            case 12: test.say("welcome-5"); break
            case 13: test.welcome.next(); break
            case 14: test.check(!w.showWelcome, "finishing closes it")
                    test.check(Browser.setting("welcome/done", false) === true, "remembered as done")
                    console.warn("DONE"); running = false; break
            }
        }
    }
}
