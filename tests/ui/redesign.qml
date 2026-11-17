import QtQuick
import f1int

// The redesigned window: default look, collapsing the tab column, Settings page, Appearance
// Studio, Customise panel, a light preset, and the theme-file checks (test profile only).
Item {
    id: test
    property var win
    property int step: 0
    function say(text) { console.warn("SHOT " + text) }
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    function settingsPage() { const l = test.win.pageAreaItem.children.find(c => c.item && c.item.category !== undefined); return l ? l.item : null }

    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: {
            const w = test.win, sb = w.sidebarItem
            switch (test.step++) {
            case 0: Browser.library.addBookmark("https://www.wikipedia.org/", "Wikipedia"); Browser.library.addBookmark("https://github.com/", "GitHub")
                    w.tabs.setPinned(w.tabs.idAt(3), true); break
            case 1: test.say("redesign-default")
                    test.check(Theme.preset === "obsidian", "default preset is Obsidian")
                    test.check(!Theme.glass, "opaque by default"); break
            case 2: sb.toggle(); break
            case 3: test.check(sb.collapsed && sb.width === sb.narrowWidth, "collapses to icons (width " + sb.width + ")")
                    test.say("redesign-collapsed"); sb.toggle(); break
            case 4: test.check(!sb.collapsed && sb.width === sb.expandedWidth, "opens again"); w.panel = "settings"; break
            case 5: test.check(test.settingsPage() !== null, "settings page opens"); test.say("settings-general"); test.settingsPage().category = "appearance"; break
            case 6: test.say("settings-appearance"); test.settingsPage().category = "data"; break
            case 7: test.say("settings-data"); Theme.settingsFilter = "tab"; break
            case 8: test.say("settings-search"); Theme.settingsFilter = ""; w.panel = "customise"; break
            case 9: test.say("customise-panel"); w.panel = ""
                    Browser.setSetting("appearance/theme", "light"); Browser.setSetting("tabs/style", "line"); break
            case 10: test.check(Theme.preset === "paper" && !Theme.dark, "light mode uses Paper"); test.say("redesign-paper")
                     Browser.setSetting("appearance/lightPreset", "frost"); Browser.setSetting("layout/tabsSide", "right"); break
            case 11: test.say("redesign-frost-right")
                     Browser.setSetting("appearance/theme", "dark"); Browser.setSetting("appearance/darkPreset", "crimson")
                     Browser.setSetting("layout/tabsSide", "left"); Browser.setSetting("tabs/style", "pill"); break
            case 12: test.say("redesign-crimson")
                     // theme files: good one passes, junk is dropped, wrong format refused
                     const good = Theme.validateTheme({ format: "f1int-theme", name: "Mine", values: { "appearance/custom/obsidian/accent": "#123456",
                                                         "appearance/roundness": 99, "evil/key": "x", "appearance/custom/obsidian/accent2": "red" } })
                     test.check(good.ok && good.theme.values["appearance/custom/obsidian/accent"] === "#123456", "theme file: colour kept")
                     test.check(good.ok && good.theme.values["appearance/roundness"] === 20, "theme file: number clamped")
                     test.check(good.ok && good.theme.values["evil/key"] === undefined && good.theme.values["appearance/custom/obsidian/accent2"] === undefined, "theme file: unknown and bad values dropped")
                     test.check(!Theme.validateTheme({ name: "x" }).ok && !Theme.validateTheme(null).ok, "theme file: wrong format refused")
                     break
            case 13: console.warn("DONE"); running = false; break
            }
        }
    }
}
