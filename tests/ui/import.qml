import QtQuick
import f1int

// Checks "Import from another browser" against the browsers installed on this computer.
// Runs in the separate test profile, so it never changes the real f1int data.
// Prints only counts, never URLs or titles.
Timer {
    property var win
    interval: 1000
    running: true
    onTriggered: {
        const profiles = Browser.library.otherBrowserProfiles()
        console.warn("PROFILES " + profiles.length)
        for (const p of profiles) {
            const r = Browser.library.importProfile(p.path)
            console.warn("IMPORT " + p.browser + " / " + p.name + ": bookmarks=" + r.bookmarks + " history=" + r.history + (r.error ? " error=" + r.error : ""))
        }
        console.warn("DONE")
    }
}
