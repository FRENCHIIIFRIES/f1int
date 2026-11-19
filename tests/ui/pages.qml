import QtQuick
import f1int

// History and Downloads as Settings pages, the Automatic look, menus, new themes,
// and site icons for Instagram (test profile only).
Item {
    id: test
    property var win
    property int step: 0
    property int waits: 0
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    function page() { const l = test.win.pageAreaItem.children.find(c => c.item && c.item.category !== undefined); return l ? l.item : null }
    Timer {
        interval: 1300
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            switch (test.step++) {
            case 0: Browser.library.addBookmark("https://www.instagram.com/", "Instagram")
                    Browser.favicons.icon("https://www.instagram.com/")   // starts fetching its icon
                    w.showPanel("history"); break
            case 1: test.check(w.panel === "settings" && test.page().category === "history", "History opens as a Settings page")
                    console.warn("SHOT page-history"); w.showPanel("downloads"); break
            case 2: test.check(test.page().category === "downloads", "Downloads opens as a Settings page")
                    console.warn("SHOT page-downloads"); w.panel = ""; break
            case 3: { const u = Browser.favicons.icon("https://www.instagram.com/")
                      if (u.toString() === "" && ++test.waits < 8) { test.step--; break }
                      test.check(u.toString().indexOf("instagram.com.png") > 0, "Instagram's logo: " + u); break }
            case 4: Theme.useAutomatic(true); w.panel = "customise"; break
            case 5: test.check(Theme.automatic && Theme.base.name === "Automatic", "Automatic look on (hue " + Theme.autoHue.toFixed(2) + ")")
                    console.warn("SHOT auto-look"); Theme.surprise(); break
            case 6: console.warn("SHOT auto-surprise"); Theme.useAutomatic(false); Browser.setSetting("appearance/darkPreset", "forest"); w.panel = ""; break
            case 7: test.check(Theme.base.name === "Forest", "new theme: Forest"); w.toolbarItem.menuRequested(w.toolbarItem); break
            case 8: console.warn("SHOT menu-forest"); console.warn("DONE"); running = false; break
            }
        }
    }
}
