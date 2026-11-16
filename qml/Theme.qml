pragma Singleton
import QtQuick
import f1int

// All colours, fonts and sizes in one place, so every file looks the same.
// Monochrome with one red accent; light mode arrives with the Settings page.
QtObject {
    property bool dark: true

    readonly property color bg:       dark ? "#000000" : "#ffffff"
    readonly property color surface:  dark ? "#0b0b0b" : "#f7f7f7"   // menus, popups, address bar
    readonly property color fg:       dark ? "#f2f2f2" : "#0a0a0a"
    readonly property color dim:      dark ? "#6b6b6b" : "#9a9a9a"   // secondary text, disabled
    readonly property color line:     dark ? "#222222" : "#e3e3e3"   // 1px dividers and borders
    readonly property color hover:    dark ? "#121212" : "#f0f0f0"
    readonly property color selected: dark ? "#1a1a1a" : "#e8e8e8"
    readonly property color press:    dark ? "#262626" : "#dedede"
    readonly property color accent:   "#D71921"                      // active / important only

    readonly property string dotFont: "Doto"   // dot-matrix: numbers, counts, headings
    readonly property int radius: 10
    readonly property int anim: Browser.reduceMotion ? 0 : 180   // ms; 0 when animations are off

    // Tab group colours: muted so the UI stays mostly black and white.
    readonly property var groupColors: ["#D71921", dark ? "#f2f2f2" : "#0a0a0a", "#8a8a8a",
                                        "#d9a62e", "#3fa877", "#4c8df6", "#9d6fd6"]
}
