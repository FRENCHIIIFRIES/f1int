pragma Singleton
import QtQuick

// All colours and sizes in one place, so every file looks the same.
// Light mode and the dot-matrix font arrive in Stage 4.
QtObject {
    property bool dark: true

    readonly property color bg:     dark ? "#000000" : "#ffffff"
    readonly property color fg:     dark ? "#ffffff" : "#000000"
    readonly property color dim:    dark ? "#5c5c5c" : "#a0a0a0"   // disabled / secondary text
    readonly property color line:   dark ? "#262626" : "#e0e0e0"   // 1px dividers
    readonly property color field:  dark ? "#0d0d0d" : "#f6f6f6"   // address bar background
    readonly property color hover:  dark ? "#161616" : "#f0f0f0"
    readonly property color press:  dark ? "#222222" : "#e4e4e4"
    readonly property color accent: "#D71921"                     // active / important only

    readonly property int radius: 8
    readonly property int tabBarWidth: 240
}
