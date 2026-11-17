import QtQuick
import f1int

// Opens the URLs given to tools\ui-test.ps1 and screenshots the page after it loads.
Timer {
    property var win
    interval: 9000
    running: true
    onTriggered: {
        console.warn("SHOT page")
        console.warn("UA " + win.profile.httpUserAgent)
        console.warn("DONE")
    }
}
