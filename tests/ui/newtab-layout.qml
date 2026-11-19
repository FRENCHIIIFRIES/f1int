import QtQuick
import f1int

// New tab page layout (test profile only): your order, clock styles, bookmark and recent
// widgets, gradient background, spacing.
Item {
    id: test
    property var win
    property int step: 0
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    function findNtp(item) {
        if (item && item.cfg !== undefined && item.order !== undefined) return item
        for (let i = 0; item && i < item.children.length; ++i) { const f = findNtp(item.children[i]); if (f) return f }
        return null
    }
    function config(change) { const c = JSON.parse(Browser.setting("newtab/config", "{}")); change(c); Browser.setSetting("newtab/config", JSON.stringify(c)) }
    Timer {
        interval: 1300
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            switch (test.step++) {
            case 0: Browser.library.addBookmark("https://www.wikipedia.org/", "Wikipedia"); Browser.library.addBookmark("https://github.com/", "GitHub")
                    Browser.setSetting("newtab/mode", "f1int"); w.openNewTab(); break
            case 1: test.config(c => {
                        c.clock = { on: true, pos: "center", size: "L", style: "analog", seconds: true }
                        c.bookmarks = { on: true, pos: "center" }
                        c.recent = { on: true, pos: "bottom" }
                        c.background = { type: "gradient", colors: ["#1b1446", "#ff7a59"], angle: 135 }
                        c.layout = { order: ["bookmarks", "clock", "search"], spacing: 30 }
                    }); break
            case 2: { const n = test.findNtp(w.contentItem)
                      test.check(n !== null, "found the new tab page")
                      test.check(n.order[0] === "bookmarks" && n.order[1] === "clock" && n.order.indexOf("todo") > 0, "your order first, newer widgets after it")
                      test.check(n.clockStyle === "analog", "analogue clock")
                      console.warn("SHOT ntp-layout"); break }
            case 3: { const n = test.findNtp(w.contentItem); n.openCustomise(); break }
            case 4: console.warn("SHOT ntp-arrange"); test.config(c => { c.clock.style = "thin"; c.background = { type: "pattern", pattern: "waves", opacity: 0.2 } }); break
            case 5: console.warn("SHOT ntp-thin-waves"); break
            case 6: console.warn("DONE"); running = false; break
            }
        }
    }
}
