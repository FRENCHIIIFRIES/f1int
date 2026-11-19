pragma Singleton
import QtQuick
import f1int

// f1int's design system. Six presets define layered surfaces (sidebar darkest, then the
// window frame, the toolbar, the address field and the page), text and two accents.
// Every value can be changed in Settings > Appearance; changes are stored per preset,
// so each preset can be tuned on its own. Everything here updates live.
QtObject {
    id: theme
    // Reading Browser.settingsRevision makes these re-evaluate whenever a setting changes.
    function setting(key, fallback) { void Browser.settingsRevision; return Browser.setting(key, fallback) }

    // ---------- presets ----------
    // frame: behind everything. sidebar: the tab column (deepest). toolbar: the bar above the page.
    // field: the address bar. tab: the open tab. panel: pages and panels. raised: menus, dialogs.
    readonly property var presets: ({
        nothing:  { name: "Nothing",  light: false, frame: "#111111", sidebar: "#090909", toolbar: "#161616", field: "#232323", tab: "#202020",
                    panel: "#141414", raised: "#1b1b1b", fg: "#ededed", dim: "#8f8f8f", accent: "#f0f0f0", accent2: "#ffc94a" },
        obsidian: { name: "Obsidian", light: false, frame: "#131316", sidebar: "#0b0b0d", toolbar: "#19191d", field: "#25252a", tab: "#232328",
                    panel: "#17171a", raised: "#1f1f24", fg: "#ececf0", dim: "#94949d", accent: "#9b7bff", accent2: "#f2c94c" },
        midnight: { name: "Midnight", light: false, frame: "#10141c", sidebar: "#0a0d13", toolbar: "#151b25", field: "#1f2633", tab: "#1d2431",
                    panel: "#131924", raised: "#1b2230", fg: "#e6eaf2", dim: "#8a94a8", accent: "#6ea8ff", accent2: "#5fd4c4" },
        crimson:  { name: "Crimson",  light: false, frame: "#131112", sidebar: "#0b0a0a", toolbar: "#191617", field: "#262223", tab: "#231f20",
                    panel: "#171415", raised: "#201c1d", fg: "#eeeaea", dim: "#978f90", accent: "#e5484d", accent2: "#d9d2d2" },
        mono:     { name: "Minimal mono", light: true, frame: "#f2f2f2", sidebar: "#e8e8e8", toolbar: "#f8f8f8", field: "#ececec", tab: "#ffffff",
                    panel: "#ffffff", raised: "#ffffff", fg: "#0a0a0a", dim: "#6b6b6b", accent: "#0a0a0a", accent2: "#d71921" },
        forest:   { name: "Forest",   light: false, frame: "#121815", sidebar: "#0b100d", toolbar: "#17201b", field: "#213028", tab: "#1f2c25",
                    panel: "#151d18", raised: "#1c2620", fg: "#e6efe9", dim: "#8fa397", accent: "#4fbf88", accent2: "#e6c25c" },
        ocean:    { name: "Ocean",    light: false, frame: "#0f171c", sidebar: "#091015", toolbar: "#142028", field: "#1c2c37", tab: "#1a2a35",
                    panel: "#121c23", raised: "#18252e", fg: "#e3eef4", dim: "#87a0ae", accent: "#3fb6d8", accent2: "#f2c94c" },
        neon:     { name: "Neon",     light: false, frame: "#0d0b14", sidebar: "#07060c", toolbar: "#13101d", field: "#1d1830", tab: "#1c1630",
                    panel: "#110e1a", raised: "#181324", fg: "#ecebff", dim: "#8f8aa8", accent: "#b16cff", accent2: "#2de2e6" },
        lavender: { name: "Lavender", light: true,  frame: "#ece9f4", sidebar: "#e2ddef", toolbar: "#f5f3fa", field: "#e6e2f0", tab: "#fdfcff",
                    panel: "#fdfcff", raised: "#ffffff", fg: "#1f1a2e", dim: "#6b6380", accent: "#7a5af5", accent2: "#d9467a" },
        sakura:   { name: "Sakura",   light: true,  frame: "#f6ebee", sidebar: "#eedde2", toolbar: "#fbf4f6", field: "#f0e2e6", tab: "#fffafb",
                    panel: "#fffafb", raised: "#ffffff", fg: "#2a1a1f", dim: "#7a5f67", accent: "#d6457a", accent2: "#3f8f66" },
        blank:    { name: "Blank",    light: false, frame: "#1d1d1d", sidebar: "#1d1d1d", toolbar: "#1d1d1d", field: "#2b2b2b", tab: "#2b2b2b",
                    panel: "#1d1d1d", raised: "#252525", fg: "#e6e6e6", dim: "#8c8c8c", accent: "#bdbdbd", accent2: "#bdbdbd" },
        paper:    { name: "Warm Paper", light: true,  frame: "#ecebe7", sidebar: "#e1e0db", toolbar: "#f5f4f1", field: "#e7e6e1", tab: "#fbfaf8",
                    panel: "#fbfaf8", raised: "#ffffff", fg: "#1c1b19", dim: "#68655f", accent: "#1c1b19", accent2: "#b7791f" },
        frost:    { name: "Frost",    light: true,  frame: "#e8edf2", sidebar: "#dbe2ea", toolbar: "#f4f7fa", field: "#e3e9ef", tab: "#ffffff",
                    panel: "#ffffff", raised: "#ffffff", fg: "#16202b", dim: "#5a6878", accent: "#2f6fdf", accent2: "#0f8f80" }
    })
    readonly property var presetOrder: ["nothing", "mono", "obsidian", "midnight", "crimson", "forest", "ocean", "neon",
                                        "paper", "frost", "lavender", "sakura", "blank"]
    readonly property var roles: ["frame", "sidebar", "toolbar", "field", "tab", "panel", "raised", "fg", "dim", "accent", "accent2",
                                  "tabIdle", "icon", "border", "hover"]
    // Parts every preset leaves to be worked out from its text colour unless you set them.
    readonly property var derived: ({ tabIdle: "#00000000", icon: "", border: "", hover: "" })

    // ---------- light / dark ----------
    readonly property string mode: setting("appearance/theme", "dark")       // dark | light | system
    readonly property bool systemDark: Qt.styleHints.colorScheme !== Qt.ColorScheme.Light
    readonly property bool wantDark: mode === "system" ? systemDark : mode !== "light"
    // One preset for dark and one for light; "System" switches between them.
    readonly property string darkPreset: validPreset(setting("appearance/darkPreset", "obsidian"), "obsidian")
    readonly property string lightPreset: validPreset(setting("appearance/lightPreset", "paper"), "paper")
    readonly property string preset: wantDark ? darkPreset : lightPreset
    readonly property var base: preset === "auto" ? autoPalette : presets[preset]
    readonly property bool dark: !base.light
    function validPreset(name, fallback) { return presets[name] || name === "auto" ? String(name) : fallback }

    // ---------- Automatic: f1int picks calm colours for you ----------
    // One hue (from your wallpaper, your Windows accent, or "Surprise me") becomes a whole
    // palette: surfaces barely tinted with it, soft text, a gentle accent and a neighbouring
    // second accent. Light or dark follows the Theme choice.
    readonly property real autoHue: {
        const own = Number(setting("appearance/autoHue", -1))
        if (own >= 0 && own <= 1) return own
        const fromDesktop = Browser.desktopHue()
        return fromDesktop >= 0 ? fromDesktop : 0.72   // nothing to go on: a quiet violet
    }
    function calmPalette(h, light) {
        const c = (s, l, hh) => String(Qt.hsla(((hh === undefined ? h : hh) % 1 + 1) % 1, s, l, 1))
        const a = h < 0.05 || h > 0.95 ? 0.93 : h   // never a red accent: a red wallpaper gets rose
        return light
            ? { name: "Automatic", light: true, frame: c(0.18, 0.93), sidebar: c(0.20, 0.89), toolbar: c(0.16, 0.965), field: c(0.16, 0.915),
                tab: c(0.30, 0.995), panel: c(0.25, 0.99), raised: "#ffffff", fg: c(0.20, 0.13), dim: c(0.10, 0.42),
                accent: c(0.50, 0.46, a), accent2: c(0.45, 0.42, a + 0.12) }
            : { name: "Automatic", light: false, frame: c(0.14, 0.085), sidebar: c(0.16, 0.055), toolbar: c(0.13, 0.11), field: c(0.12, 0.16),
                tab: c(0.13, 0.15), panel: c(0.12, 0.095), raised: c(0.12, 0.13), fg: c(0.12, 0.92), dim: c(0.08, 0.63),
                accent: c(0.55, 0.68, a), accent2: c(0.55, 0.72, a + 0.12) }
    }
    readonly property var autoPalette: calmPalette(autoHue, !wantDark)
    readonly property bool automatic: darkPreset === "auto" || lightPreset === "auto"
    function useAutomatic(on) {
        Browser.setSetting("appearance/darkPreset", on ? "auto" : "obsidian")
        Browser.setSetting("appearance/lightPreset", on ? "auto" : "paper")
    }
    function surprise() {   // a fresh calm hue, not too close to the current one
        let h = Math.random()
        if (Math.abs(h - autoHue) < 0.12) h = (h + 0.35) % 1
        Browser.setSetting("appearance/autoHue", Math.round(h * 1000) / 1000)
    }

    // A colour for a role: your change for this preset if you made one, else the preset's.
    function role(name) {
        const own = String(setting("appearance/custom/" + preset + "/" + name, ""))
        return colourOk(own) ? own : base[name] !== undefined ? base[name] : derived[name]
    }
    // "#rrggbb", or "#aarrggbb" (Qt's order) for see-through colours.
    function colourOk(c) { return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(String(c)) }
    function isCustomised(name) { return /^#/.test(String(setting("appearance/custom/" + preset + "/" + name, ""))) }

    // ---------- surfaces ----------
    // Sidebar depth: -1 lighter ... 0 as designed ... +1 deeper.
    readonly property real sidebarDepth: Number(setting("sidebar/depth", 0))
    readonly property color frame:   role("frame")
    readonly property color sidebar: sidebarDepth >= 0 ? Qt.darker(role("sidebar"), 1 + sidebarDepth * (dark ? 0.6 : 0.12))
                                                       : Qt.lighter(role("sidebar"), 1 - sidebarDepth * (dark ? 0.6 : 0.06))
    readonly property color toolbar: role("toolbar")
    readonly property color field:   role("field")
    readonly property color tab:     role("tab")
    readonly property color bg:      role("panel")      // pages, panels
    readonly property color surface: role("raised")     // menus, dialogs, cards
    readonly property color fg:      role("fg")
    readonly property color dim:     role("dim")        // secondary text

    // Frosted glass (Windows 11, off by default): the frame lets the blurred desktop through.
    readonly property bool glass: Qt.platform.os === "windows" && setting("appearance/glass", false)
    readonly property real glassTint: Number(setting("appearance/glassTint", 0.7))   // 0 = clear, 1 = solid
    readonly property color chromeSolid: frame
    readonly property color chrome: glass ? Qt.rgba(frame.r, frame.g, frame.b, glassTint) : frame

    // Lines, hover and press tints come from the text colour, so they suit any surface.
    readonly property real lineStrength: Number(setting("appearance/lines", 1))      // 0 none ... 2 strong
    function ink(alpha) { return Qt.rgba(fg.r, fg.g, fg.b, alpha) }
    readonly property color line:     role("border") !== "" ? role("border") : ink((dark ? 0.08 : 0.10) * lineStrength)
    readonly property color hover:    role("hover") !== "" ? role("hover") : ink(dark ? 0.06 : 0.05)
    readonly property color tabIdle:  role("tabIdle")                       // tabs that aren't open
    readonly property color iconColor: role("icon") !== "" ? role("icon") : fg
    readonly property color press:    ink(dark ? 0.12 : 0.10)
    readonly property color selected: tab                                   // the open tab

    // ---------- accents ----------
    readonly property color accent:  role("accent")       // focus, on-switches, main buttons, progress
    readonly property color accent2: role("accent2")      // small highlights: stars, sound, badges
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.16)
    readonly property color textOnAccent:  brightness(accent.toString()) > 0.6 ? "#0b0b0c" : "#ffffff"
    readonly property color textOnAccent2: brightness(accent2.toString()) > 0.6 ? "#0b0b0c" : "#ffffff"
    // 0 (black) ... 1 (white), from a "#rrggbb" colour.
    function brightness(hex) {
        const n = parseInt(String(hex).replace("#", "").slice(-6), 16)
        return (0.299 * ((n >> 16) & 255) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255)) / 255
    }

    // ---------- type ----------
    readonly property real textScale: Number(setting("appearance/textScale", 1.0))
    function px(size) { return Math.round(size * textScale) }          // every font size goes through this
    readonly property string dotFont: "Doto"
    // Numbers and small labels can use the dot-matrix face (on by default: part of f1int's look).
    readonly property string numberFont: setting("appearance/dotNumbers", true) ? dotFont : Qt.application.font.family

    // ---------- shape and spacing ----------
    readonly property int radius: Number(setting("appearance/roundness", 10))     // 0 = square ... 16 = very round
    readonly property int cardRadius: radius + 2
    readonly property string density: setting("appearance/density", "comfortable")  // compact | comfortable | spacious
    readonly property int gap: density === "compact" ? 4 : density === "spacious" ? 10 : 6
    readonly property int pad: density === "compact" ? 12 : density === "spacious" ? 22 : 16   // inside panels
    readonly property int inset: Number(setting("appearance/inset", 8))           // space around the page

    // ---------- tabs ----------
    readonly property string tabStyle: String(setting("tabs/style", "pill"))      // pill | square | line
    readonly property int rowHeight: Number(setting("tabs/height", density === "compact" ? 30 : density === "spacious" ? 40 : 34))
    readonly property int tabGap: Number(setting("tabs/gap", 2))
    readonly property int tabRadius: tabStyle === "square" ? Math.min(4, radius) : tabStyle === "line" ? 0 : radius

    // ---------- sidebar ----------
    readonly property int iconSize: Number(setting("sidebar/iconSize", 16))
    readonly property bool sidebarLabels: setting("sidebar/labels", false)
    // Footer shortcuts, in your order; hide one by taking it out.
    readonly property var allShortcuts: ["bookmarks", "history", "downloads", "passwords", "search", "settings"]
    readonly property var shortcuts: {
        try { const list = JSON.parse(String(setting("sidebar/shortcuts", ""))); if (Array.isArray(list)) return list.filter(s => allShortcuts.indexOf(s) >= 0) }
        catch (e) {}
        return ["bookmarks", "history", "passwords", "settings", "search"]
    }
    readonly property bool showNewTabRow: setting("sidebar/newTabRow", true)
    readonly property bool showPinned: setting("sidebar/pinned", true)

    // ---------- layout ----------
    readonly property bool tabsOnRight: setting("layout/tabsSide", "left") === "right"
    // Where the address bar goes: "page" = above the page, beside the tab column (default),
    // "window" = a row across the whole window top, "sidebar" = at the top of the tab column.
    readonly property string addressPlace: String(setting("layout/address", "page"))
    readonly property bool addressInSidebar: addressPlace === "sidebar"
    readonly property bool showHome: setting("layout/showHome", false)
    readonly property bool showDownloads: setting("layout/showDownloads", true)
    readonly property bool showTabCount: setting("layout/showTabCount", true)
    readonly property bool showRam: setting("layout/showRam", true)
    readonly property bool showBookmarksBar: setting("layout/bookmarksBar", true)

    // ---------- motion ----------
    readonly property string motion: setting("appearance/motion", "normal")    // off | fast | normal | relaxed
    readonly property int anim: Browser.reduceMotion || motion === "off" ? 0 : motion === "fast" ? 110 : motion === "relaxed" ? 260 : 180
    readonly property bool hoverEffects: setting("appearance/hoverEffects", true)

    // ---------- backgrounds ----------
    // The window (behind everything), the tab column and the toolbar can each have a colour,
    // a gradient, a picture or a pattern, per preset. Stored as JSON.
    readonly property var surfaces: ["window", "sidebar", "toolbar"]
    readonly property var fillDefaults: ({ type: "solid", colors: [], angle: 160, image: "", fit: "fill", position: "center",
                                           dim: 0, blur: 0, pattern: "dots", patternColor: "", patternScale: 1, patternOpacity: 0.14, opacity: 1 })
    function fill(surface) {
        let own = {}
        try { own = JSON.parse(String(setting("appearance/fill/" + preset + "/" + surface, "{}"))) || {} } catch (e) {}
        return Object.assign({}, fillDefaults, own)
    }
    function setFill(surface, change) {
        const now = fill(surface)
        Browser.setSetting("appearance/fill/" + preset + "/" + surface, JSON.stringify(Object.assign(now, change)))
    }
    readonly property var windowFill: fill("window")
    readonly property var sidebarFill: fill("sidebar")
    readonly property var toolbarFill: fill("toolbar")
    // A picture anywhere behind the tab column or toolbar: they may be see-through then.
    readonly property bool hasWallpaper: windowFill.type !== "solid"

    // ---------- icons, loading, headings ----------
    readonly property real iconWeight: Number(setting("appearance/iconWeight", 1.75))   // line thickness of f1int's icons
    readonly property var iconMap: { try { return JSON.parse(String(setting("appearance/icons", "{}"))) || {} } catch (e) { return {} } }
    function iconSource(glyph) {
        return !glyph ? "" : iconMap[glyph] ? "image://icons/asset/" + iconMap[glyph] : "image://icons/" + glyph + "?w=" + iconWeight
    }
    readonly property string loaderStyle: String(setting("appearance/loader", "dots"))   // dots | spinner | pulse | bar | image
    readonly property string loaderImage: String(setting("appearance/loaderImage", ""))
    readonly property string headingStyle: String(setting("appearance/headingFont", "system"))   // system | dot
    readonly property string headingFamily: headingStyle === "dot" ? dotFont : Qt.application.font.family

    // Tab group colours (work on light and dark surfaces).
    readonly property var groupColors: ["#9b7bff", "#f2c94c", "#4c8df6", "#3fa877", "#e0569b", "#e5484d", "#8a8a8a"]

    // ---------- saved themes ----------
    // Every setting that belongs to "how f1int looks": saved together, restored together.
    readonly property var lookKeys: ["appearance/theme", "appearance/darkPreset", "appearance/lightPreset", "appearance/glass",
        "appearance/glassTint", "appearance/lines", "appearance/textScale", "appearance/dotNumbers", "appearance/roundness",
        "appearance/density", "appearance/inset", "appearance/motion", "appearance/hoverEffects", "tabs/style", "tabs/height",
        "tabs/gap", "sidebar/depth", "sidebar/iconSize", "sidebar/labels", "sidebar/shortcuts", "sidebar/newTabRow",
        "sidebar/pinned", "layout/tabsSide", "layout/address", "layout/showHome", "layout/showDownloads", "layout/showTabCount",
        "layout/showRam", "layout/bookmarksBar", "appearance/iconWeight", "appearance/icons", "appearance/loader",
        "appearance/loaderImage", "appearance/headingFont"]
    // Per-preset keys: colours of every part and the backgrounds.
    function presetKeys() {
        const keys = []
        for (const p of presetOrder) {
            for (const r of roles) keys.push("appearance/custom/" + p + "/" + r)
            for (const f of surfaces) keys.push("appearance/fill/" + p + "/" + f)
        }
        return keys
    }
    function snapshot() {   // the current look as plain data
        const values = {}
        for (const k of lookKeys) values[k] = Browser.setting(k, null)
        for (const k of presetKeys()) {
            const v = String(Browser.setting(k, ""))
            if (v !== "") values[k] = v
        }
        return values
    }
    function apply(values, remember) {   // put a saved look back (remember: false = not as an undo step)
        history.quiet = true   // one step in the undo list, not hundreds
        for (const k of lookKeys) Browser.resetSetting(k)
        for (const k of presetKeys()) Browser.resetSetting(k)
        for (const k in values)
            if ((lookKeys.indexOf(k) >= 0 || k.startsWith("appearance/custom/") || k.startsWith("appearance/fill/")) && values[k] !== null && values[k] !== undefined)
                Browser.setSetting(k, values[k])
        history.quiet = false
        if (remember === false) history.last = JSON.stringify(snapshot())
        else history.note()
    }
    readonly property var savedThemes: {
        try { const l = JSON.parse(String(setting("appearance/saved", "[]"))); return Array.isArray(l) ? l : [] } catch (e) { return [] }
    }
    function storeThemes(list) { Browser.setSetting("appearance/saved", JSON.stringify(list)) }

    // Theme files (.f1theme): JSON with name, author, description, version and look values.
    // Only known settings with sane values get through: a theme can't run code or touch
    // anything but the look. Returns { ok, theme, error }.
    readonly property var choices: ({
        "appearance/theme": ["dark", "light", "system"], "appearance/darkPreset": presetOrder, "appearance/lightPreset": presetOrder,
        "appearance/density": ["compact", "comfortable", "spacious"], "appearance/motion": ["off", "fast", "normal", "relaxed"],
        "tabs/style": ["pill", "square", "line"], "layout/tabsSide": ["left", "right"], "layout/address": ["page", "window", "sidebar"],
        "appearance/loader": ["dots", "spinner", "pulse", "bar", "image"], "appearance/headingFont": ["system", "dot"]
    })
    readonly property var ranges: ({
        "appearance/glassTint": [0, 1], "appearance/lines": [0, 2], "appearance/textScale": [0.8, 1.5], "appearance/roundness": [0, 20],
        "appearance/inset": [0, 24], "tabs/height": [24, 48], "tabs/gap": [0, 10], "sidebar/depth": [-1, 1], "sidebar/iconSize": [12, 24],
        "appearance/iconWeight": [0.75, 3]
    })
    readonly property var assetId: /^[0-9a-f]{20}\.(png|jpg|svg|gif|webp)$/
    // A background from a file, with every field checked and anything unknown dropped.
    function cleanFill(raw) {
        let f = raw
        if (typeof raw === "string") { try { f = JSON.parse(raw) } catch (e) { return null } }
        if (!f || typeof f !== "object") return null
        const pick = (v, list, d) => list.indexOf(v) >= 0 ? v : d
        const num = (v, lo, hi, d) => { const n = Number(v); return isFinite(n) ? Math.min(hi, Math.max(lo, n)) : d }
        return {
            type: pick(f.type, ["solid", "gradient", "image", "pattern"], "solid"),
            colors: Array.isArray(f.colors) ? f.colors.filter(colourOk).slice(0, 3) : [],
            angle: num(f.angle, 0, 360, 160), image: assetId.test(String(f.image)) ? String(f.image) : "",
            fit: pick(f.fit, ["fill", "fit", "stretch", "tile", "center"], "fill"),
            position: pick(f.position, ["center", "top", "bottom", "left", "right"], "center"),
            dim: num(f.dim, 0, 0.9, 0), blur: num(f.blur, 0, 1, 0),
            pattern: pick(f.pattern, ["dots", "grid", "lines", "diagonal", "waves", "cross"], "dots"),
            patternColor: colourOk(f.patternColor) ? f.patternColor : "", patternScale: num(f.patternScale, 0.5, 3, 1),
            patternOpacity: num(f.patternOpacity, 0, 1, 0.14), opacity: num(f.opacity, 0.2, 1, 1)
        }
    }
    function validateTheme(data) {
        if (!data || typeof data !== "object" || data.format !== "f1int-theme")
            return { ok: false, error: qsTr("This isn't an f1int theme file.") }
        if (typeof data.name !== "string" || data.name.trim() === "" || data.name.length > 60)
            return { ok: false, error: qsTr("The theme needs a name (up to 60 characters).") }
        const values = {}
        const v = data.values || {}
        for (const k in v) {
            const x = v[k]
            const custom = /^appearance\/custom\/([a-z]+)\/([a-zA-Z0-9]+)$/.exec(k)
            const fillKey = /^appearance\/fill\/([a-z]+)\/([a-z]+)$/.exec(k)
            if (custom) {
                if (presets[custom[1]] && roles.indexOf(custom[2]) >= 0 && colourOk(x)) values[k] = String(x)
            } else if (fillKey) {
                const f = presets[fillKey[1]] && surfaces.indexOf(fillKey[2]) >= 0 ? cleanFill(x) : null
                if (f) values[k] = JSON.stringify(f)
            } else if (k === "appearance/icons") {
                let m = x
                if (typeof x === "string") { try { m = JSON.parse(x) } catch (e) { m = null } }
                const out = {}
                const names = Browser.assets.iconNames
                for (const n in (m || {})) if (names.indexOf(n) >= 0 && assetId.test(String(m[n]))) out[n] = String(m[n])
                values[k] = JSON.stringify(out)
            } else if (k === "appearance/loaderImage") {
                if (assetId.test(String(x))) values[k] = String(x)
            } else if (choices[k]) {
                if (choices[k].indexOf(x) >= 0) values[k] = x
            } else if (ranges[k]) {
                const n = Number(x)
                if (isFinite(n)) values[k] = Math.min(ranges[k][1], Math.max(ranges[k][0], n))
            } else if (k === "sidebar/shortcuts") {
                if (Array.isArray(x)) values[k] = JSON.stringify(x.filter(s => allShortcuts.indexOf(s) >= 0))
                else if (typeof x === "string") { try { const l = JSON.parse(x); if (Array.isArray(l)) values[k] = JSON.stringify(l.filter(s => allShortcuts.indexOf(s) >= 0)) } catch (e) {} }
            } else if (lookKeys.indexOf(k) >= 0 && (typeof x === "boolean" || x === "true" || x === "false")) {
                values[k] = x === true || x === "true"   // (the Windows registry hands booleans back as text)
            }   // anything else is dropped
        }
        const text = (t, n) => typeof t === "string" ? t.slice(0, n) : ""
        // Pictures and icons travel inside the file; each is checked again (Assets.addBase64)
        // and the theme is pointed at the checked copies.
        const renamed = {}
        const files = (data.assets && typeof data.assets === "object") ? data.assets : {}
        for (const id in files) {
            if (!assetId.test(id) || typeof files[id] !== "string") continue
            const kind = String(values["appearance/icons"] || "").indexOf(id) >= 0 ? "icon"
                       : id === values["appearance/loaderImage"] ? "loader" : "image"
            const r = Browser.assets.addBase64(files[id], id, kind)
            if (r.ok) renamed[id] = r.id
        }
        for (const k in values) {
            let text = String(values[k])
            for (const id of Object.keys(files)) if (text.indexOf(id) >= 0) text = text.split(id).join(renamed[id] || "")
            if (k === "appearance/loaderImage" && !Browser.assets.url(text).toString()) { delete values[k]; continue }
            if (typeof values[k] === "string") values[k] = text
        }
        return { ok: true, theme: { name: data.name.trim(), author: text(data.author, 60), description: text(data.description, 300),
                                    version: text(String(data.version || "1"), 20), values: values } }
    }
    function themeFile(theme) {   // the portable form of a saved theme, with its pictures and icons inside
        const assets = {}
        const all = JSON.stringify(theme.values)
        const ids = all.match(/[0-9a-f]{20}\.(png|jpg|svg|gif|webp)/g) || []
        for (const id of ids) if (!assets[id]) { const b = Browser.assets.base64(id); if (b) assets[id] = b }
        return JSON.stringify({ format: "f1int-theme", version: theme.version || "1", name: theme.name, author: theme.author || "",
                                description: theme.description || "", values: theme.values, assets: assets }, null, 2)
    }

    // ---------- undo ----------
    // Every change to the look is remembered (the last 25, kept across restarts), so any
    // experiment can be taken back, and earlier looks restored.
    readonly property QtObject history: QtObject {
        id: hist
        property bool quiet: false
        property string last: ""
        readonly property var steps: { try { const l = JSON.parse(String(setting("appearance/undo", "[]"))); return Array.isArray(l) ? l : [] } catch (e) { return [] } }
        property Timer settle: Timer { interval: 700; onTriggered: hist.note() }
        function note() {
            if (quiet) return
            const now = JSON.stringify(snapshot())
            if (last !== "" && now !== last) Browser.setSetting("appearance/undo", JSON.stringify(steps.concat([JSON.parse(last)]).slice(-25)))
            last = now
        }
        function undo() {
            const list = steps.slice()
            if (list.length === 0) return
            const prev = list.pop()
            Browser.setSetting("appearance/undo", JSON.stringify(list))
            apply(prev, false)
        }
    }
    readonly property bool canUndo: { void Browser.settingsRevision; return history.steps.length > 0 }
    property Connections watch: Connections {
        target: Browser
        function onSettingChanged() { if (!history.quiet) history.settle.restart() }
    }
    Component.onCompleted: history.last = JSON.stringify(snapshot())

    // Settings search (not saved): rows whose words don't match hide themselves.
    property string settingsFilter: ""
}
