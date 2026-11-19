import QtQuick
import f1int

// Theme engine walk-through (test profile only): backgrounds, see-through, icons, loaders,
// undo, and a theme file that carries its picture.
Item {
    id: test
    property var win
    property int step: 0
    property var themeData: null
    readonly property url picture: Qt.resolvedUrl("../../resources/logo/f1int-512.png")
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    function say(n) { console.warn("SHOT " + n) }
    function page() { const l = test.win.pageAreaItem.children.find(c => c.item && c.item.category !== undefined); return l ? l.item : null }
    function studio(item) {   // the ThemeStudio inside the settings page
        if (item && item.cat !== undefined && item.colourPicker !== undefined) return item
        for (let i = 0; item && i < item.children.length; ++i) { const f = studio(item.children[i]); if (f) return f }
        return null
    }
    Timer {
        interval: 1300
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            switch (test.step++) {
            case 0: w.panel = "settings"; break
            case 1: test.page().category = "appearance"; break
            case 2: test.say("studio-themes"); test.studio(test.page()).cat = "backgrounds"; break
            case 3: {
                const r = Browser.assets.add(test.picture, "image")
                test.check(r.ok, "picture stored: " + (r.error || r.id))
                Theme.setFill("window", { type: "gradient", colors: ["#1b1446", "#6e4aff", "#ff7a59"], angle: 135 })
                Theme.setFill("sidebar", { type: "image", image: r.id, fit: "fill", dim: 0.3, opacity: 0.85 })
                Theme.setFill("toolbar", { type: "pattern", pattern: "grid", patternOpacity: 0.12 })
                break
            }
            case 4: test.check(Theme.hasWallpaper && Theme.windowFill.colors.length === 3, "gradient window set")
                    test.check(Theme.sidebarFill.type === "image" && Browser.assets.url(Theme.sidebarFill.image).toString() !== "", "tab column picture set")
                    test.say("studio-backgrounds"); break
            case 5: w.panel = ""; break
            case 6: test.say("custom-window"); w.panel = "settings"; break
            case 7: test.page().category = "appearance"; break
            case 8: test.studio(test.page()).cat = "icons"
                    Browser.setSetting("appearance/iconWeight", 2.5); Browser.setSetting("appearance/loader", "spinner"); break
            case 9: test.check(Theme.iconSource("star").indexOf("w=2.5") > 0, "icons drawn heavier")
                    test.say("studio-icons"); test.studio(test.page()).cat = "colours"
                    Browser.setSetting("appearance/custom/" + Theme.preset + "/tabIdle", "#22ffffff"); break
            case 10: test.check(Theme.tabIdle.a > 0.1 && Theme.tabIdle.a < 0.2, "see-through colour for other tabs")
                     test.say("studio-colours")
                     // a theme file with the picture inside
                     test.themeData = JSON.parse(Theme.themeFile({ name: "Sunset", author: "test", values: Theme.snapshot() }))
                     test.check(Object.keys(test.themeData.assets).length === 1, "the theme file carries its picture"); break
            case 11: Browser.resetSetting("appearance/fill/" + Theme.preset + "/sidebar"); break
            case 12: test.check(Theme.sidebarFill.type === "solid", "background reset"); Theme.history.undo(); break
            case 13: test.check(Theme.sidebarFill.type === "image", "undo brings it back"); {
                     const r = Theme.validateTheme(test.themeData)
                     test.check(r.ok && /[0-9a-f]{20}.(png|jpg)/.test(String(r.theme.values["appearance/fill/" + Theme.preset + "/sidebar"])), "the theme file imports with its picture")
                     const evil = JSON.parse(JSON.stringify(test.themeData))
                     for (const id in evil.assets) evil.assets[id] = Qt.btoa("<html><script>alert(1)</script></html>")
                     const bad = Theme.validateTheme(evil)
                     test.check(bad.ok && String(bad.theme.values["appearance/fill/" + Theme.preset + "/sidebar"]).indexOf("\"image\":\"\"") > 0, "a fake picture in a theme file is refused") }
                     break
            case 14: console.warn("DONE"); running = false; break
            }
        }
    }
}
