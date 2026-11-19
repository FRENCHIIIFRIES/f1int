import QtQuick
import f1int

// Renaming a bookmark from the Bookmarks panel (test profile only).
Item {
    id: test
    property var win
    property int step: 0
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    function find(item) {   // the rename box inside the open panel
        if (item && item.bookmark !== undefined && item.openFor !== undefined) return item
        for (let i = 0; item && i < item.children.length; ++i) { const f = find(item.children[i]); if (f) return f }
        for (let i = 0; item && item.data && i < item.data.length; ++i) if (item.data[i] && item.data[i].bookmark !== undefined && item.data[i].openFor !== undefined) return item.data[i]
        return null
    }
    Timer {
        interval: 1200
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            switch (test.step++) {
            case 0: Browser.library.addBookmark("https://github.com/", "GitHub"); w.panel = "bookmarks"; break
            case 1: { const box = test.find(w.pageAreaItem); test.check(box !== null, "rename box in the Bookmarks panel")
                      box.openFor(Browser.library.bookmarks()[0]); console.warn("SHOT rename-bookmark"); break }
            case 2: { const box = test.find(w.pageAreaItem); box.contentItem.children[2].text = "  My code  "; box.save(); break }
            case 3: test.check(Browser.library.bookmarks()[0].title === "My code", "renamed (" + Browser.library.bookmarks()[0].title + ")")
                    console.warn("DONE"); running = false; break
            }
        }
    }
}
