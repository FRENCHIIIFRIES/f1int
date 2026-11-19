import QtQuick
import QtWebEngine
import f1int

// The saved-accounts list under a login box, and site icons for bookmarks (test profile only).
Item {
    id: test
    property var win
    property int step: 0
    property int waits: 0
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    readonly property string loginPage: "<html><body style='background:#fff;font:16px sans-serif;padding:40px'>" +
        "<h2>Log in to Example</h2><form action='/done'><p><input id=email name=email type=email autofocus></p>" +
        "<p><input name=pw type=password></p><button>Log in</button></form></body></html>"
    function picker() { return test.win.accountPickerItem }
    Timer {
        interval: 1400
        repeat: true
        running: true
        onTriggered: {
            const w = test.win, v = Browser.passwords
            if ([1, 2, 7].indexOf(test.step) >= 0 && w.view.loading) return
            switch (test.step++) {
            case 0:
                v.setUp("test master password", false)
                v.save("https://login.test/", "ana@example.com", "Very-Strong-Pass-42")
                v.save("https://login.test/", "work@example.com", "Another-Strong-Pass-7")
                w.view.loadHtml(test.loginPage, "https://login.test/")
                break
            case 1: break   // the page puts the cursor in the email box itself (autofocus): no click needed
            case 2: {
                const p = test.picker()
                test.check(p && p.opened && p.logins.length === 2, "two saved accounts listed under the box the page selected itself")
                console.warn("SHOT autofill-picker")
                w.fillAs(p.logins.find(l => l.username === "work@example.com").id)
                break
            }
            case 3:
                w.view.runJavaScript("document.querySelector('[name=email]').value + '|' + document.querySelector('[name=pw]').value",
                                     (r) => test.check(r === "work@example.com|Another-Strong-Pass-7", "picking one fills both boxes"))
                v.lock()
                break
            case 4: w.view.runJavaScript("document.getElementById('email').blur(); document.getElementById('email').focus()"); break
            case 5: {
                const p = test.picker()
                test.check(p && p.opened && p.locked, "locked: offers to unlock")
                console.warn("SHOT autofill-locked")
                p.close()
                w.view.url = "https://www.wikipedia.org/"
                break
            }
            case 6: break
            case 7: break
            case 8: {   // the icon a page showed is kept for its bookmarks (fetched over the network: wait up to ~10 s)
                const u = Browser.favicons.icon("https://www.wikipedia.org/")
                if (u.toString() === "" && ++test.waits < 8) { test.step--; break }
                test.check(u.toString().indexOf("wikipedia.org.png") > 0, "site icon kept for bookmarks: " + u)
                break
            }
            case 9: w.showSettings("passwords"); break
            case 10: console.warn("SHOT settings-passwords"); break
            case 11: console.warn("DONE"); running = false; break
            }
        }
    }
}
