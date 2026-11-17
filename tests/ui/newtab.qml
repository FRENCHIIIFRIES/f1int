import QtQuick
import f1int

// UI walk-through of the new tab page: default look, all widgets on, a picture
// background (the f1int logo PNG), the customise panel and the colour wheel.
Item {
    id: test
    property var win
    property int step: 0
    readonly property url picture: Qt.resolvedUrl("../../resources/logo/f1int-512.png")
    function say(text) { console.warn("SHOT " + text) }
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    function findNtp(item) {   // the NewTabPage object, wherever it is in the window
        if (item && item.cfg !== undefined && item.focusSearch !== undefined) return item
        for (let i = 0; item && i < item.children.length; ++i) { const f = findNtp(item.children[i]); if (f) return f }
        return null
    }
    function config(change) {
        const c = JSON.parse(Browser.setting("newtab/config", "{}"))
        change(c)
        Browser.setSetting("newtab/config", JSON.stringify(c))
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            switch (test.step++) {
            case 0: w.openNewTab(); break
            case 1: test.check(w.showNewTabPage, "new tab shows the new tab page")
                    test.check(w.view.url.toString() === "", "empty tab loaded no web page")
                    test.say("ntp-default"); break
            case 2: test.config(c => {
                        for (const k of ["date", "note", "todo", "status"]) c[k] = { on: true }
                        c.shortcuts = { on: true, items: [{ title: "wikipedia", url: "https://www.wikipedia.org" },
                                                          { title: "github", url: "https://github.com" },
                                                          { title: "youtube", url: "https://www.youtube.com" }] }
                        c.todo.items = [{ text: "Finish f1int", done: false }, { text: "Try the colour wheel", done: true }]
                        c.clock = { on: true, size: "L", seconds: true }
                    }); break
            case 3: test.say("ntp-widgets"); break
            case 4: test.config(c => { c.background = { type: "image", image: test.picture.toString(), dim: 0.5 } }); break
            case 5: test.say("ntp-picture"); break
            case 6: { const n = test.findNtp(w.contentItem); test.check(n !== null, "found new tab page"); if (n) n.openCustomise(); break }
            case 7: test.say("ntp-customise"); break
            case 8: { const n = test.findNtp(w.contentItem); if (n) n.openColorPicker(); break }
            case 9: test.say("colour-wheel"); break
            case 10: console.warn("DONE"); running = false; break
            }
        }
    }
}
