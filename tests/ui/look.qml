import QtQuick
import f1int

// Screenshots of the look in several Appearance settings (test profile only).
// Glass is off here: window-only screenshots can't capture the frosted glass.
Item {
    id: test
    property var win
    property int step: 0
    function say(text) { console.warn("SHOT " + text) }
    function set(k, v) { Browser.setSetting(k, v) }

    Timer {
        interval: 1600
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            const tabs = w.tabs
            switch (test.step++) {
            case 0: {
                console.warn("ARGS " + Qt.application.arguments.length + " TABS " + tabs.count)
                test.set("appearance/glass", false)
                const g = tabs.addGroup("Reading", Theme.groupColors[1])
                tabs.setGroup(tabs.idAt(2), g)
                tabs.setGroup(tabs.idAt(3), g)
                tabs.setPinned(tabs.idAt(4), true)
                break
            }
            case 1: test.say("look-dark"); break
            case 2: w.panel = "settings"; break
            case 3: test.say("look-settings"); break
            case 4: w.panel = ""; test.set("appearance/theme", "light"); break
            case 5: test.say("look-light"); break
            case 6: test.set("layout/tabsSide", "right"); test.set("layout/address", "page"); test.set("appearance/tint", "mist")
                    test.set("appearance/roundness", 4); test.set("appearance/accent", "#3fa877"); break
            case 7: test.say("look-light-right-top"); break
            case 8: test.set("appearance/theme", "dark"); test.set("appearance/tint", "midnight"); test.set("layout/tabsSide", "left")
                    test.set("layout/address", "sidebar"); test.set("appearance/roundness", 14); test.set("appearance/accent", "auto")
                    test.set("appearance/density", "spacious"); w.openNewTab(); break
            case 9: test.say("look-midnight-newtab"); break
            case 10: test.set("appearance/density", "comfortable"); test.set("appearance/customTint", "#23324a")
                     test.set("appearance/tint", "custom"); w.panel = "passwords"; break
            case 11: console.warn("ACCENT " + Theme.accent + " ON " + Theme.textOnAccent + " STR " + Theme.accent.toString() + " B " + Theme.brightness(Theme.accent.toString())); test.say("look-passwords"); break
            case 12: console.warn("DONE"); running = false; break
            }
        }
    }
}
