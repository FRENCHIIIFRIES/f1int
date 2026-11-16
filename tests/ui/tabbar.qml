import QtQuick
import f1int

// UI walk-through of the tab bar, run inside f1int:
//   F1INT_UI_TEST=tests/ui/tabbar.qml f1int a.com b.com c.com d.com
// Prints "SHOT <name>" when the window is ready for a screenshot (tools take it from outside).
Item {
    id: test
    property var win
    property int step: 0

    function say(text) { console.warn("SHOT " + text) }
    Connections {   // log every tab switch, to catch unexpected ones
        target: Browser.tabs
        function onCurrentIdChanged() {
            console.warn("step " + test.step + ": current tab -> " + Browser.tabs.currentId + " " + Browser.tabs.tab(Browser.tabs.currentId).title)
        }
    }

    Timer {
    interval: 1200
    repeat: true
    running: true
    onTriggered: {
        const win = test.win
        const tabs = Browser.tabs
        switch (test.step++) {
        case 0: {   // pin the last tab, put tabs 2 and 3 in a group
            tabs.setPinned(tabs.idAt(3), true)
            const g = tabs.addGroup("Work", Theme.groupColors[3])
            tabs.setGroup(tabs.idAt(2), g)
            tabs.setGroup(tabs.idAt(3), g)
            break
        }
        case 1: say("grouped"); break
        case 2: win.tabMenuItem.tabId = tabs.idAt(2)
                win.tabMenuItem.tab = tabs.tab(tabs.idAt(2))
                win.tabMenuItem.popup(win.sidebarItem, 120, 230); break
        case 3: say("tabmenu"); break
        case 4: win.tabMenuItem.close(); win.groupPopupItem.create(tabs.idAt(1)); break
        case 5: say("grouppopup"); break
        case 6: win.groupPopupItem.close()
                tabs.editGroup(tabs.groups[0].id, { collapsed: true }); break
        case 7: say("groupcollapsed"); break
        case 8: tabs.editGroup(tabs.groups[0].id, { collapsed: false })
                win.sidebarItem.toggle(); break
        case 9: say("narrow"); break
        case 10: win.sidebarItem.toggle()   // put the setting back
                 win.newTab(); win.toolbarItem.focusAddress(); break
        case 11: say("newtab"); break
        case 12: console.warn("DONE tabs=" + tabs.count + " groups=" + tabs.groups.length); running = false; break
        }
    }
    }
}
