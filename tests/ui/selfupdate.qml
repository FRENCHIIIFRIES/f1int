import QtQuick
import f1int

// Runs the real updater in a copied (old) install: check, download, verify, swap, restart.
// Only use on a throwaway copy, never the real install.
Item {
    id: test
    property var win
    property int waits: 0
    Component.onCompleted: {
        console.warn("VERSION " + Browser.updater.current + " supported=" + Browser.updater.supported)
        if (Browser.updater.current !== "0.2.2") { console.warn("DONE"); Qt.quit(); return }
        Browser.updater.check()
    }
    Connections {
        target: Browser.updater
        function onChanged() {
            const u = Browser.updater
            console.warn("STATE " + u.state + " " + (u.error || "") + " " + Math.round(u.progress * 100))
            if (u.state === "available") u.download()
            else if (u.state === "ready") u.install()
            else if (u.state === "upToDate" || u.state === "error") { console.warn("DONE"); Qt.quit() }
        }
    }
}
