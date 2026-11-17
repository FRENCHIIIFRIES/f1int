pragma Singleton
import QtQuick
import f1int

// f1int's look, "clean and calm": soft greys, the system font, gentle rounded shapes,
// and the accent colour only for things that matter (focus, on-switches, main buttons).
// Every value here follows Settings > Appearance live, so the whole browser is customisable.
QtObject {
    // Reading Browser.settingsRevision makes these re-evaluate whenever a setting changes.
    function setting(key, fallback) { void Browser.settingsRevision; return Browser.setting(key, fallback) }

    // ---------- theme and tint ----------
    readonly property string mode: setting("appearance/theme", "dark")       // dark | light | system
    // Tint presets: two dark (graphite, midnight), two light (paper, mist), or "custom":
    // any colour you pick. With a custom tint, light or dark text follows the colour itself.
    readonly property string tintSetting: String(setting("appearance/tint", ""))
    readonly property bool customTint: tintSetting === "custom"
    readonly property string customColor: String(setting("appearance/customTint", "#2b2d42"))
    readonly property bool dark: customTint ? brightness(customColor) < 0.5
                               : mode === "system" ? Qt.styleHints.colorScheme !== Qt.ColorScheme.Light : mode !== "light"
    readonly property var tints: ({
        graphite: { chrome: "#1e1f22", panel: "#26272b", raised: "#2e2f34" },
        midnight: { chrome: "#121317", panel: "#191a1f", raised: "#202128" },
        paper:    { chrome: "#f1f0ee", panel: "#ffffff", raised: "#ffffff" },
        mist:     { chrome: "#e9edf1", panel: "#f8fafc", raised: "#ffffff" }
    })
    readonly property string tint: customTint ? "custom"
                                   : tints[tintSetting] && (dark === (tintSetting === "graphite" || tintSetting === "midnight")) ? tintSetting
                                   : dark ? "graphite" : "paper"
    // Custom: panels a step lighter (on dark colours) or near-white (on light ones).
    readonly property var t: customTint ? { chrome: customColor,
                                            panel: dark ? Qt.lighter(customColor, 1.18) : Qt.lighter(customColor, 1.06),
                                            raised: dark ? Qt.lighter(customColor, 1.32) : Qt.lighter(customColor, 1.08) }
                                        : tints[tint]

    // Frosted glass (Windows 11): the window background lets the blurred desktop through.
    readonly property bool glass: Qt.platform.os === "windows" && setting("appearance/glass", true)
    readonly property real glassTint: Number(setting("appearance/glassTint", 0.55))   // 0 = clear, 1 = solid

    readonly property color chromeSolid: t.chrome
    // Behind the tab bar and around the page: the tint, see-through when glass is on.
    readonly property color chrome:  glass ? Qt.rgba(chromeSolid.r, chromeSolid.g, chromeSolid.b, glassTint) : chromeSolid
    readonly property color bg:      t.panel        // pages, panels
    readonly property color surface: t.raised       // menus, dialogs, cards
    readonly property color fg:      dark ? "#e9e9ec" : "#1d1d20"
    readonly property color dim:     dark ? "#9c9da3" : "#6c6d72"   // secondary text (4.5:1 on its background)
    readonly property color line:    dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color field:   dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.045)  // address bar, search boxes
    readonly property color hover:   dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color selected: dark ? Qt.rgba(1, 1, 1, 0.10) : "#ffffff"              // the open tab
    readonly property color press:   dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)

    // ---------- accent ----------
    // "auto" (default): chosen from the tint. Otherwise a colour you picked, or "fg" (plain).
    readonly property string accentSetting: String(setting("appearance/accent", "auto"))
    readonly property color accent: accentSetting === "auto" ? autoAccent : accentSetting === "fg" ? fg : accentSetting
    // The automatic accent: grey tints get a calm blue; a coloured tint gets a matching hue,
    // nudged a little round the colour wheel. Never red, orange or yellow. Lighter on dark
    // themes and deeper on light ones, so it stands out clearly against the background.
    readonly property color autoAccent: {
        let hue = chromeSolid.hslHue
        if (hue < 0 || chromeSolid.hslSaturation < 0.12)
            hue = 0.6                        // greys: blue
        else
            hue = (hue + 0.06) % 1           // coloured tint: a neighbouring hue
        if (hue < 0.17 || hue > 0.94)
            hue = 0.6                        // skip red / orange / yellow
        return Qt.hsla(hue, 0.65, dark ? 0.66 : 0.46, 1)
    }
    // Text on the accent colour: black on light accents, white on everything else.
    readonly property color textOnAccent: brightness(accent.toString()) > 0.65 ? "#000000" : "#ffffff"
    // 0 (black) ... 1 (white), from a "#rrggbb" colour.
    function brightness(hex) {
        const n = parseInt(String(hex).replace("#", "").slice(-6), 16)
        return (0.299 * ((n >> 16) & 255) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255)) / 255
    }
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.16)   // selected chips, focus glow

    // ---------- type ----------
    readonly property real textScale: Number(setting("appearance/textScale", 1.0))
    function px(size) { return Math.round(size * textScale) }          // every font size goes through this
    readonly property string dotFont: "Doto"
    // Numbers (tab count, memory, clock) can use the dot-matrix font if you like it.
    readonly property string numberFont: setting("appearance/dotNumbers", false) ? dotFont : Qt.application.font.family

    // ---------- shape and spacing ----------
    readonly property int radius: Number(setting("appearance/roundness", 10))     // 0 = square ... 16 = very round
    readonly property int cardRadius: radius + 2
    readonly property string density: setting("appearance/density", "comfortable")  // compact | comfortable | spacious
    readonly property int rowHeight: density === "compact" ? 30 : density === "spacious" ? 40 : 34
    readonly property int gap: density === "compact" ? 4 : density === "spacious" ? 10 : 6
    readonly property int pad: density === "compact" ? 12 : density === "spacious" ? 22 : 16   // inside panels
    readonly property int inset: Number(setting("appearance/inset", 8))           // space around the page

    // ---------- layout ----------
    readonly property bool tabsOnRight: setting("layout/tabsSide", "left") === "right"
    // Where the address bar goes: "window" = its own row across the top of the window (default),
    // "page" = above the page only, "sidebar" = at the top of the tab bar.
    readonly property string addressPlace: String(setting("layout/address", "window"))
    readonly property bool addressInSidebar: addressPlace === "sidebar"
    readonly property bool showHome: setting("layout/showHome", true)
    readonly property bool showDownloads: setting("layout/showDownloads", true)
    readonly property bool showTabCount: setting("layout/showTabCount", true)
    readonly property bool showRam: setting("layout/showRam", true)

    // ---------- motion ----------
    readonly property string motion: setting("appearance/motion", "normal")    // off | fast | normal
    readonly property int anim: Browser.reduceMotion || motion === "off" ? 0 : motion === "fast" ? 110 : 180

    // Tab group colours.
    readonly property var groupColors: ["#D71921", "#4c8df6", "#3fa877", "#9d6fd6", "#e0569b", "#8a8a8a", dark ? "#e9e9ec" : "#1d1d20"]
}
