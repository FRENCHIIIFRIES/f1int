import QtQuick
import f1int

// Screenshots of the everyday pages after the readability pass (test profile only).
Item {
    id: test
    property var win
    property int step: 0
    function page() { const l = test.win.pageAreaItem.children.find(c => c.item && c.item.category !== undefined); return l ? l.item : null }
    Timer {
        interval: 1300
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            switch (test.step++) {
            case 0: Browser.setSetting("appearance/glass", true); Browser.library.addBookmark("https://github.com/", "GitHub"); w.panel = "downloads"; break
            case 1: console.warn("SHOT read-downloads"); w.panel = "history"; break
            case 2: console.warn("SHOT read-history"); w.panel = "settings"; break
            case 3: console.warn("SHOT read-settings"); test.page().category = "privacy"; break
            case 4: console.warn("SHOT read-privacy"); test.page().category = "passwords"; break
            case 5: console.warn("SHOT read-passwords"); w.panel = "customise"; break
            case 6: console.warn("SHOT read-customise"); console.warn("DONE"); running = false; break
            }
        }
    }
}
