import QtQuick
import f1int

// Opens the Settings panel and reports each step (to find a crash).
Timer {
    property var win
    property int step: 0
    interval: 1500
    repeat: true
    running: true
    onTriggered: {
        console.warn("STEP " + step)
        if (step === 1) win.panel = "settings"
        if (step === 3) { console.warn("DONE"); running = false }
        step++
    }
}
