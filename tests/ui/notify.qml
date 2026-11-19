import QtQuick
import f1int

// Site notifications (test profile only): the site asks, you allow, it notifies, a card shows.
// Also: tab groups and the New tab row under the last tab, for a screenshot.
Item {
    id: test
    property var win
    property int step: 0
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    readonly property string page: "<html><body style='font:16px sans-serif;padding:40px'><h2>Notify test</h2>" +
        "<script>function ask(){ Notification.requestPermission().then(p => document.title = 'perm:' + p) }" +
        "function send(){ new Notification('Build finished', { body: 'f1int 0.2.1 is ready' }) }</script></body></html>"
    Timer {
        interval: 1300
        repeat: true
        running: true
        onTriggered: {
            const w = test.win, tabs = w.tabs
            if ([1, 2].indexOf(test.step) >= 0 && w.view.loading) return
            switch (test.step++) {
            case 0: w.view.loadHtml(test.page, "https://notify.test/"); break
            case 1: w.view.runJavaScript("ask()"); break
            case 2: test.check(w.notifyPrompt !== null, "the site's request shows a prompt"); console.warn("SHOT notify-ask"); break
            case 3: if (w.notifyPrompt) { w.notifyPrompt.grant(); w.notifyPrompt = null } break
            case 4: w.view.runJavaScript("document.title", (t) => test.check(t === "perm:granted", "allowed (" + t + ")")); w.view.runJavaScript("send()"); break
            case 5: test.check(w.toasts.length === 1 && w.toasts[0].title === "Build finished", "the notification shows as a card")
                    { const g = tabs.addGroup("Work", Theme.groupColors[0]); tabs.setGroup(tabs.idAt(0), g) }
                    console.warn("SHOT notify-card"); break
            case 6: console.warn("DONE"); running = false; break
            }
        }
    }
}
