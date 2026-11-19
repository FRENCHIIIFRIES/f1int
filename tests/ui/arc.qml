import QtQuick
import f1int

// Lists the other browsers found on this computer and dry-runs an import from Arc
// (counts only: nothing is added, the other browser is only read from a copy).
Item {
    id: test
    property var win
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    Timer {
        interval: 1500
        running: true
        onTriggered: {
            const found = Browser.library.otherBrowserProfiles()
            console.warn("FOUND " + found.map(p => p.browser + "/" + p.name).join(", "))
            const arc = found.filter(p => p.browser === "Arc")
            test.check(arc.length > 0, "Arc found")
            for (const p of arc) {
                const r = Browser.library.importProfile(p.path, { dryRun: true })
                test.check(!r.error, "Arc " + p.name + ": " + r.bookmarks + " saved tabs, " + r.history + " history, search " + (r.search || "-") + (r.error ? " " + r.error : ""))
            }
            test.check(Browser.library.bookmarks().length === 0, "dry run added nothing")
            console.warn("DONE")
        }
    }
}
