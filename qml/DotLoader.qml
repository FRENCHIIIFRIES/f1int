import QtQuick
import f1int

// Loading indicator: three dots that light up one after another.
// Stands still (all dots half lit) when the system turns animations off.
Row {
    id: loader
    property color color: Theme.accent
    property int dot: 3
    spacing: 2

    Repeater {
        model: 3
        Rectangle {
            required property int index
            width: loader.dot
            height: loader.dot
            radius: loader.dot / 2
            color: loader.color
            opacity: Browser.reduceMotion ? 0.6 : 0.2
            // Each dot waits its turn; every loop is 750 ms so they stay in step.
            SequentialAnimation on opacity {
                running: loader.visible && !Browser.reduceMotion
                loops: Animation.Infinite
                PauseAnimation { duration: index * 150 }
                NumberAnimation { to: 1; duration: 150 }
                NumberAnimation { to: 0.2; duration: 300 }
                PauseAnimation { duration: (2 - index) * 150 }
            }
        }
    }
}
