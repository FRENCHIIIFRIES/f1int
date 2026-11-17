pragma Singleton
import QtQuick
import f1int

// All colours, fonts and sizes in one place, so every file looks the same.
// Follows the settings live: theme (dark / light / system) and accent colour.
QtObject {
    // Reading Browser.settingsRevision makes these re-evaluate whenever a setting changes.
    function setting(key, fallback) { void Browser.settingsRevision; return Browser.setting(key, fallback) }

    readonly property string mode: setting("appearance/theme", "dark")   // dark | light | system
    readonly property bool dark: mode === "system" ? Qt.styleHints.colorScheme !== Qt.ColorScheme.Light : mode !== "light"

    readonly property color bg:       dark ? "#000000" : "#ffffff"
    readonly property color surface:  dark ? "#0b0b0b" : "#f6f6f6"   // menus, panels, address bar
    readonly property color fg:       dark ? "#f2f2f2" : "#0a0a0a"
    readonly property color dim:      dark ? "#6b6b6b" : "#8f8f8f"   // secondary text, disabled
    readonly property color line:     dark ? "#222222" : "#e2e2e2"   // 1px dividers and borders
    readonly property color hover:    dark ? "#121212" : "#efefef"
    readonly property color selected: dark ? "#1a1a1a" : "#e6e6e6"
    readonly property color press:    dark ? "#262626" : "#dadada"
    // Active / important states only. Red by default; white, grey or any colour in Settings.
    readonly property color accent: {
        const a = String(setting("appearance/accent", "#D71921"))
        return a === "fg" ? fg : a
    }
    // Text drawn on top of the accent colour (dark text on a white accent, white otherwise).
    readonly property color onAccent: Qt.colorEqual(accent, "#ffffff") || accent.hslLightness > 0.7 ? "#000000" : "#ffffff"

    readonly property string dotFont: "Doto"   // dot-matrix: numbers, counts, headings
    readonly property int radius: 10
    readonly property int anim: Browser.reduceMotion ? 0 : 180   // ms; 0 when animations are off

    // Tab group colours: muted so the UI stays mostly black and white.
    readonly property var groupColors: ["#D71921", dark ? "#f2f2f2" : "#0a0a0a", "#8a8a8a",
                                        "#d9a62e", "#3fa877", "#4c8df6", "#9d6fd6"]
}
