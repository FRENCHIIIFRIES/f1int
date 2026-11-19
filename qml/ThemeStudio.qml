import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import f1int

// Settings > Appearance: the theme library (built-in presets and your own themes, with a
// live preview before you apply one), the colour editor for every surface, shape, type,
// effects, and saving, sharing and importing themes (.f1theme files).
ColumnLayout {
    id: studio
    spacing: 22
    function get(key, fallback) { void Browser.settingsRevision; return Browser.setting(key, fallback) }
    function set(key, value) { Browser.setSetting(key, value) }

    // What the big preview shows: null = the current look, or a card you clicked.
    property var previewing: null      // { kind: "preset"|"saved", id, colours, name }
    function coloursOfPreset(id) { return Theme.presets[id] }
    // Colours of a saved theme: its preset, with its own changes on top.
    function coloursOfSaved(t) {
        const v = t.values || {}
        const dark = (v["appearance/theme"] || "dark") !== "light"
        const p = dark ? (v["appearance/darkPreset"] || "obsidian") : (v["appearance/lightPreset"] || "paper")
        const c = Object.assign({}, Theme.presets[p] || Theme.presets.obsidian)
        for (const r of Theme.roles) if (v["appearance/custom/" + p + "/" + r]) c[r] = v["appearance/custom/" + p + "/" + r]
        return c
    }
    readonly property var current: { const c = {}; for (const r of Theme.roles) c[r] = Theme[r === "panel" ? "bg" : r === "raised" ? "surface" : r]; return c }
    readonly property var shown: previewing ? previewing.colours : current

    function applyPreset(id) {
        const light = Theme.presets[id].light
        set(light ? "appearance/lightPreset" : "appearance/darkPreset", id)
        if (Theme.mode !== "system") set("appearance/theme", light ? "light" : "dark")
        previewing = null
    }
    function applySaved(t) { Theme.apply(t.values); previewing = null }
    function saveAs(name, extra) {
        const list = Theme.savedThemes.slice()
        list.push(Object.assign({ id: Date.now().toString(36), name: name, author: "", description: "", version: "1",
                                  source: "mine", favourite: false, values: Theme.snapshot() }, extra || {}))
        Theme.storeThemes(list)
    }
    function updateSaved(id, change) {
        Theme.storeThemes(Theme.savedThemes.map(t => t.id === id ? Object.assign({}, t, change) : t))
    }

    property alias colourPicker: colourPopup

    // ---------- the live preview: a small f1int window ----------
    component MiniWindow: Rectangle {
        id: mini
        property var c: ({})
        property bool tabsRight: Theme.tabsOnRight
        property bool live: false     // the current look: show its backgrounds too
        radius: 10
        color: c.frame || "#000"
        border.width: 1
        border.color: Theme.line
        clip: true
        Fill { anchors.fill: parent; visible: mini.live; spec: Theme.windowFill; base: mini.c.frame || "#000" }
        Rectangle {   // the tab column
            id: miniSide
            x: mini.tabsRight ? parent.width - width : 0
            width: parent.width * 0.26
            height: parent.height
            radius: 10
            color: mini.live && Theme.sidebarFill.type !== "solid" ? "transparent" : mini.c.sidebar || "#000"
            Fill { anchors.fill: parent; visible: mini.live && Theme.sidebarFill.type !== "solid"; spec: Theme.sidebarFill; base: mini.c.sidebar || "#000" }
            Column {
                x: 8; y: 10; spacing: 5
                Rectangle { width: 10; height: 10; radius: 2; color: Theme.dark ? "#e8434f" : "#a61b2a" }
                Item { width: 1; height: 4 }
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        width: miniSide.width - 16; height: 12; radius: 4
                        color: index === 1 ? mini.c.tab : mini.c.tabIdle || "transparent"
                        Rectangle { x: 5; anchors.verticalCenter: parent.verticalCenter; width: parent.width * (0.7 - parent.index * 0.08); height: 3; radius: 1.5; color: mini.c.dim || "#888" }
                    }
                }
            }
        }
        Rectangle {   // toolbar band with the address field
            x: mini.tabsRight ? 0 : miniSide.width
            width: parent.width - miniSide.width
            height: 26
            color: mini.live && Theme.toolbarFill.type !== "solid" ? "transparent" : mini.c.toolbar || "#000"
            Fill { anchors.fill: parent; visible: mini.live && Theme.toolbarFill.type !== "solid"; spec: Theme.toolbarFill; base: mini.c.toolbar || "#000" }
            Rectangle { x: 10; y: 6; width: parent.width - 20; height: 14; radius: 7; color: mini.c.field || "#000"
                Rectangle { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 5; height: 5; radius: 2.5; color: mini.c.accent2 || "#fc0" } }
        }
        Rectangle {   // the page
            x: (mini.tabsRight ? 0 : miniSide.width) + 7
            y: 33
            width: parent.width - miniSide.width - 14
            height: parent.height - 40
            radius: 6
            color: mini.c.panel || "#000"
            border.width: 1
            border.color: Theme.line
            Rectangle { x: 12; y: 12; width: parent.width * 0.4; height: 6; radius: 3; color: mini.c.fg || "#fff" }
            Rectangle { x: 12; y: 25; width: parent.width - 24; height: 3; radius: 1.5; color: mini.c.dim || "#888" }
            Rectangle { x: 12; y: 33; width: parent.width - 44; height: 3; radius: 1.5; color: mini.c.dim || "#888" }
            Rectangle { x: 12; y: 46; width: 38; height: 13; radius: 6.5; color: mini.c.accent || "#88f" }
            Rectangle { x: 56; y: 46; width: 13; height: 13; radius: 6.5; color: mini.c.accent2 || "#fc0" }
        }
    }

    // A theme in the library: a small preview of it and its name.
    component ThemeCard: Rectangle {
        id: card
        property string name
        property string subtitle
        property var colours: ({})
        property bool active: false      // the one in use
        property bool chosen: false      // the one being previewed
        property bool favourite: false
        property bool hasMenu: false     // your own themes have options
        signal clicked()
        signal doubleClicked()
        signal menuRequested(Item item)
        width: 164
        height: 132
        radius: Theme.cardRadius
        color: cardHover.hovered && Theme.hoverEffects ? Theme.hover : "transparent"
        border.width: chosen || active ? 2 : 1
        border.color: chosen ? Theme.accent2 : active ? Theme.accent : Theme.line
        Accessible.role: Accessible.Button
        Accessible.name: name
        HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
        MiniWindow { x: 8; y: 8; width: parent.width - 16; height: 82; c: card.colours; tabsRight: false; radius: 7 }
        Text {
            x: 10; y: 96
            width: parent.width - (card.hasMenu ? 44 : 20)
            text: (card.favourite ? "★ " : "") + card.name
            color: Theme.fg
            font.pixelSize: Theme.px(12)
            font.weight: card.active ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
        Text { x: 10; y: 112; text: card.active ? qsTr("In use") : card.subtitle; color: card.active ? Theme.accent : Theme.dim; font.pixelSize: Theme.px(10) }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => m.button === Qt.RightButton ? card.menuRequested(card) : card.clicked()
            onDoubleClicked: card.doubleClicked()
        }
        IconButton {
            id: more
            visible: card.hasMenu
            x: parent.width - width - 4; y: 92
            implicitWidth: 26; implicitHeight: 26; iconSize: 14
            iconName: "more"
            iconColor: Theme.dim
            tip: qsTr("Theme options")
            onClicked: card.menuRequested(more)
        }
    }

    // ---------- categories: simple first, the deep stuff a click away ----------
    property string cat: "library"
    readonly property bool searching: Theme.settingsFilter !== ""
    RowLayout {
        Layout.fillWidth: true
        visible: !studio.searching
        spacing: 10
        Ui.Segmented {
            options: [{ label: qsTr("Themes"), value: "library" }, { label: qsTr("Colours"), value: "colours" },
                      { label: qsTr("Backgrounds"), value: "backgrounds" }, { label: qsTr("Shape and type"), value: "shape" },
                      { label: qsTr("Icons and motion"), value: "icons" }]
            value: studio.cat
            onPicked: (v) => studio.cat = v
        }
        Item { Layout.fillWidth: true }
        Ui.Pill {
            text: qsTr("Undo")
            enabled: Theme.canUndo
            onClicked: Theme.history.undo()
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Take back the last change to the look (the last 25 are kept)")
        }
    }

    // ---------- library ----------
    Ui.Section {
        visible: studio.searching || studio.cat === "library"
        title: qsTr("Theme library")
        Item {
            Layout.fillWidth: true
            implicitHeight: libraryColumn.implicitHeight + 32
            ColumnLayout {
                id: libraryColumn
                x: 16; y: 16
                width: parent.width - 32
                spacing: 16
                RowLayout {
                    spacing: 18
                    MiniWindow {
                        Layout.preferredWidth: 300
                        Layout.preferredHeight: 180
                        c: studio.shown
                        live: studio.previewing === null
                        Behavior on color { ColorAnimation { duration: Theme.anim * 2 } }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: studio.previewing ? qsTr("Previewing %1").arg(studio.previewing.name) : qsTr("Your current look")
                            color: Theme.fg
                            font.pixelSize: Theme.px(16)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: studio.previewing ? qsTr("Nothing has changed yet. Apply it, or pick another.")
                                                    : qsTr("Click a theme below to preview it here first.")
                            color: Theme.dim
                            font.pixelSize: Theme.px(12)
                        }
                        Row {
                            spacing: 8
                            visible: studio.previewing !== null
                            Ui.Pill {
                                primary: true
                                text: qsTr("Apply")
                                onClicked: studio.previewing.kind === "preset" ? studio.applyPreset(studio.previewing.id)
                                                                              : studio.applySaved(Theme.savedThemes.find(t => t.id === studio.previewing.id))
                            }
                            Ui.Pill { text: qsTr("Cancel"); onClicked: studio.previewing = null }
                        }
                        Ui.Segmented {
                            options: [{ label: qsTr("Dark"), value: "dark" }, { label: qsTr("Light"), value: "light" }, { label: qsTr("System"), value: "system" }]
                            value: Theme.mode
                            onPicked: (v) => studio.set("appearance/theme", v)
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Templates: pick one, change anything, save it as yours"); color: Theme.dim; font.pixelSize: Theme.px(12); Layout.fillWidth: true }
                    Ui.Pill {
                        text: qsTr("Start from scratch")
                        onClicked: { studio.applyPreset("blank"); studio.cat = "colours" }
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: Theme.presetOrder
                        ThemeCard {
                            required property string modelData
                            name: Theme.presets[modelData].name
                            colours: Theme.presets[modelData]
                            active: Theme.preset === modelData
                            chosen: studio.previewing && studio.previewing.id === modelData
                            onClicked: studio.previewing = { kind: "preset", id: modelData, colours: colours, name: name }
                            onDoubleClicked: studio.applyPreset(modelData)
                        }
                    }
                }
                Text { text: qsTr("Your themes and looks (each keeps its colours, backgrounds, icons, tab and sidebar setup)"); color: Theme.dim; font.pixelSize: Theme.px(12) }
                Text {
                    visible: Theme.savedThemes.length === 0
                    text: qsTr("Save your look below to keep it as a theme, or import a .f1theme file.")
                    color: Theme.dim
                    font.pixelSize: Theme.px(12)
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        // Favourites first.
                        model: Theme.savedThemes.slice().sort((a, b) => (b.favourite === true) - (a.favourite === true))
                        ThemeCard {
                            required property var modelData
                            name: modelData.name
                            subtitle: modelData.source === "imported" ? qsTr("Imported") + (modelData.author ? " · " + modelData.author : "") : ""
                            favourite: modelData.favourite === true
                            hasMenu: true
                            colours: studio.coloursOfSaved(modelData)
                            chosen: studio.previewing && studio.previewing.id === modelData.id
                            onClicked: studio.previewing = { kind: "saved", id: modelData.id, colours: colours, name: name }
                            onDoubleClicked: studio.applySaved(modelData)
                            onMenuRequested: (item) => { savedMenu.theme = modelData; savedMenu.popup(item, 0, item.height) }
                        }
                    }
                }
                Row {
                    spacing: 8
                    Ui.Field { id: newName; width: 200; placeholderText: qsTr("Name for this look") }
                    Ui.Pill {
                        text: qsTr("Save as theme")
                        enabled: newName.text.trim() !== ""
                        onClicked: { studio.saveAs(newName.text.trim()); newName.text = "" }
                    }
                    Ui.Pill { text: qsTr("Import…"); onClicked: importDialog.open() }
                }
                Text {
                    id: libraryMessage
                    visible: text !== ""
                    color: Theme.dim
                    font.pixelSize: Theme.px(12)
                }
            }
        }
    }

    F1Menu {
        id: savedMenu
        property var theme: null
        MenuItem { text: qsTr("Apply"); onTriggered: studio.applySaved(savedMenu.theme) }
        MenuItem { text: qsTr("Update with my current look"); onTriggered: studio.updateSaved(savedMenu.theme.id, { values: Theme.snapshot() }) }
        MenuItem {
            text: savedMenu.theme && savedMenu.theme.favourite ? qsTr("Remove from favourites") : qsTr("Add to favourites")
            onTriggered: studio.updateSaved(savedMenu.theme.id, { favourite: !savedMenu.theme.favourite })
        }
        MenuItem { text: qsTr("Rename…"); onTriggered: { renameField.text = savedMenu.theme.name; renamePopup.open() } }
        MenuItem { text: qsTr("Duplicate"); onTriggered: studio.saveAs(qsTr("%1 copy").arg(savedMenu.theme.name), { values: savedMenu.theme.values, description: savedMenu.theme.description || "" }) }
        MenuItem { text: qsTr("Export…"); onTriggered: { exportDialog.theme = savedMenu.theme; exportDialog.open() } }
        MenuItem { text: qsTr("Delete"); onTriggered: Theme.storeThemes(Theme.savedThemes.filter(t => t.id !== savedMenu.theme.id)) }
    }
    Popup {
        id: renamePopup
        anchors.centerIn: Overlay.overlay
        modal: true
        padding: 18
        background: Rectangle { color: Theme.surface; radius: Theme.cardRadius; border.width: 1; border.color: Theme.line }
        contentItem: Column {
            spacing: 12
            Text { text: qsTr("Rename theme"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold }
            Ui.Field { id: renameField; width: 240; onAccepted: renameOk.clicked() }
            Row {
                spacing: 8
                Ui.Pill { id: renameOk; primary: true; text: qsTr("Rename"); enabled: renameField.text.trim() !== ""
                          onClicked: { studio.updateSaved(savedMenu.theme.id, { name: renameField.text.trim().slice(0, 60) }); renamePopup.close() } }
                Ui.Pill { text: qsTr("Cancel"); onClicked: renamePopup.close() }
            }
        }
    }
    FileDialog {
        id: exportDialog
        property var theme: null
        fileMode: FileDialog.SaveFile
        defaultSuffix: "f1theme"
        nameFilters: [qsTr("f1int themes (*.f1theme)")]
        currentFile: theme ? "file:///" + theme.name.replace(/[^A-Za-z0-9 _-]/g, "") + ".f1theme" : ""
        onAccepted: libraryMessage.text = Browser.writeTextFile(selectedFile, Theme.themeFile(theme))
                    ? qsTr("Exported %1.").arg(theme.name) : qsTr("Couldn't write that file.")
    }
    FileDialog {
        id: importDialog
        nameFilters: [qsTr("f1int themes (*.f1theme *.json)")]
        onAccepted: {
            let data = null
            try { data = JSON.parse(Browser.readTextFile(selectedFile)) } catch (e) {}
            const r = Theme.validateTheme(data)
            if (!r.ok) { libraryMessage.text = r.error; return }
            studio.saveAs(r.theme.name, Object.assign(r.theme, { source: "imported" }))
            libraryMessage.text = qsTr("Imported %1. Click it to preview.").arg(r.theme.name)
        }
    }

    // ---------- colour editor ----------
    Ui.Section {
        visible: studio.searching || studio.cat === "colours"
        title: qsTr("Colours of %1").arg(Theme.base.name)
        Repeater {
            model: [
                { role: "frame", label: qsTr("Window"), hint: qsTr("Around the page") },
                { role: "sidebar", label: qsTr("Tab column"), hint: qsTr("Also the title bar; tabs that aren't open sit on it") },
                { role: "toolbar", label: qsTr("Toolbar"), hint: qsTr("The bar with the address field") },
                { role: "field", label: qsTr("Address field"), hint: qsTr("Also search boxes") },
                { role: "tab", label: qsTr("Open tab"), hint: qsTr("Also picked options") },
                { role: "panel", label: qsTr("Page and panels") },
                { role: "raised", label: qsTr("Menus and cards") },
                { role: "fg", label: qsTr("Text and icons") },
                { role: "dim", label: qsTr("Secondary text") },
                { role: "accent", label: qsTr("Accent"), hint: qsTr("Buttons, switches, focus, progress") },
                { role: "accent2", label: qsTr("Second accent"), hint: qsTr("Stars, sound, small highlights") },
                { role: "tabIdle", label: qsTr("Other tabs"), hint: qsTr("Tabs that aren't open (see-through by default)") },
                { role: "icon", label: qsTr("Icons"), hint: qsTr("Empty = the text colour") },
                { role: "border", label: qsTr("Borders and separators"), hint: qsTr("Empty = from the text colour and the Borders slider") },
                { role: "hover", label: qsTr("Hover highlight"), hint: qsTr("Empty = a light wash of the text colour") }]
            Ui.SettingRow {
                id: colourRow
                required property var modelData
                label: modelData.label
                hint: modelData.hint || ""
                Row {
                    spacing: 8
                    IconButton {
                        visible: { void Browser.settingsRevision; return Theme.isCustomised(colourRow.modelData.role) }
                        iconName: "reload"
                        iconSize: 14
                        iconColor: Theme.dim
                        tip: qsTr("Back to the preset's colour")
                        onClicked: Browser.resetSetting("appearance/custom/" + Theme.preset + "/" + colourRow.modelData.role)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Ui.Field {
                        id: hex
                        width: 92
                        font.family: Theme.numberFont
                        text: { void Browser.settingsRevision; return String(Theme.role(colourRow.modelData.role)).toUpperCase() }
                        placeholderText: qsTr("auto")
                        // 6 digits, or 8 for see-through colours (#AARRGGBB, the first two are the opacity).
                        validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,8}/ }
                        onEditingFinished: {
                            const v = (text.startsWith("#") ? text : "#" + text).toLowerCase()
                            if (Theme.colourOk(v)) studio.set("appearance/custom/" + Theme.preset + "/" + colourRow.modelData.role, v)
                        }
                        Accessible.name: colourRow.modelData.label + " " + qsTr("hex code")
                    }
                    Rectangle {
                        width: 32; height: 32; radius: Theme.radius
                        color: Theme.colourOk(hex.text) ? hex.text : "transparent"
                        border.width: 1; border.color: Theme.line
                        PatternCanvas { anchors.fill: parent; anchors.margins: 2; z: -1; kind: "grid"; size: 0.4; opacity: 0.3 }   // shows see-through
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Pick a colour for %1").arg(colourRow.modelData.label)
                        MouseArea { anchors.fill: parent; onClicked: colourPopup.openFor(colourRow.modelData.role) }
                    }
                }
            }
        }
        Ui.SettingRow {
            label: qsTr("Borders")
            hint: qsTr("How visible the hairlines between surfaces are")
            Ui.Slide { width: 160; from: 0; to: 2; value: Theme.lineStrength; onMoved: studio.set("appearance/lines", Math.round(value * 10) / 10) }
        }
        Ui.SettingRow {
            label: qsTr("Start this theme over")
            hint: qsTr("Puts every colour of %1 back as designed").arg(Theme.base.name)
            last: true
            Ui.Pill { text: qsTr("Reset colours"); onClicked: { for (const r of Theme.roles) Browser.resetSetting("appearance/custom/" + Theme.preset + "/" + r) } }
        }
    }
    Popup {
        id: colourPopup
        property string role: "accent"
        property var done: null           // set instead of `role` to use the picked colour elsewhere
        property real alpha: 1
        function openFor(r) {
            role = r; done = null
            const c = Theme.colourOk(Theme.role(r)) ? Qt.color(Theme.role(r)) : Theme.fg
            wheel.color = Qt.rgba(c.r, c.g, c.b, 1); alpha = c.a; open()
        }
        function pick(colour, callback) {
            done = callback
            const c = Theme.colourOk(colour) ? Qt.color(colour) : Theme.accent
            wheel.color = Qt.rgba(c.r, c.g, c.b, 1); alpha = c.a; open()
        }
        anchors.centerIn: Overlay.overlay
        width: 280
        padding: 18
        modal: true
        background: Rectangle { color: Theme.surface; radius: Theme.cardRadius; border.width: 1; border.color: Theme.line }
        contentItem: Column {
            spacing: 12
            ColorWheel {
                id: wheel
                width: parent.width
                onPicked: (c) => {
                    const value = Qt.rgba(c.r, c.g, c.b, colourPopup.alpha).toString()   // "#aarrggbb" when see-through
                    if (colourPopup.done) colourPopup.done(value)
                    else studio.set("appearance/custom/" + Theme.preset + "/" + colourPopup.role, value)
                    colourPopup.close()
                }
            }
            Row {   // opacity: 0 = see-through ... 100 = solid
                spacing: 10
                Text { text: qsTr("Opacity"); color: Theme.dim; font.pixelSize: Theme.px(12); anchors.verticalCenter: parent.verticalCenter }
                Ui.Slide { width: 150; from: 0; to: 1; value: colourPopup.alpha; onMoved: colourPopup.alpha = Math.round(value * 100) / 100 }
                Text { text: Math.round(colourPopup.alpha * 100) + "%"; color: Theme.fg; font.family: Theme.numberFont; font.pixelSize: Theme.px(12); anchors.verticalCenter: parent.verticalCenter }
            }
            Row {   // RGB, for exact values
                spacing: 6
                Repeater {
                    model: ["R", "G", "B"]
                    Ui.Field {
                        required property string modelData
                        required property int index
                        width: 72
                        placeholderText: modelData
                        text: Math.round([wheel.color.r, wheel.color.g, wheel.color.b][index] * 255)
                        validator: IntValidator { bottom: 0; top: 255 }
                        onEditingFinished: {
                            const rgb = [wheel.color.r, wheel.color.g, wheel.color.b]
                            rgb[index] = Math.min(255, Number(text)) / 255
                            wheel.color = Qt.rgba(rgb[0], rgb[1], rgb[2], 1)
                        }
                        Accessible.name: modelData
                    }
                }
            }
        }
    }

    // ---------- shape and type ----------
    BackgroundEditor { visible: studio.searching || studio.cat === "backgrounds"; Layout.fillWidth: true; picker: studio.colourPicker }

    Ui.Section {
        visible: studio.searching || studio.cat === "shape"
        title: qsTr("Shape and type")
        Ui.SettingRow {
            label: qsTr("Corners")
            Row {
                spacing: 10
                Ui.Slide { width: 140; from: 0; to: 16; stepSize: 1; value: Theme.radius; onMoved: studio.set("appearance/roundness", value) }
                Text { text: Theme.radius === 0 ? qsTr("Square") : Theme.radius + " px"; color: Theme.dim; font.pixelSize: Theme.px(12); font.family: Theme.numberFont; width: 52; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Ui.SettingRow {
            label: qsTr("Density")
            Ui.Segmented {
                options: [{ label: qsTr("Compact"), value: "compact" }, { label: qsTr("Comfortable"), value: "comfortable" }, { label: qsTr("Spacious"), value: "spacious" }]
                value: Theme.density
                onPicked: (v) => { studio.set("appearance/density", v); Browser.resetSetting("tabs/height") }
            }
        }
        Ui.SettingRow {
            label: qsTr("Space around the page")
            Ui.Segmented {
                options: [{ label: qsTr("None"), value: 0 }, { label: qsTr("Small"), value: 8 }, { label: qsTr("Large"), value: 16 }]
                value: Theme.inset
                onPicked: (v) => studio.set("appearance/inset", v)
            }
        }
        Ui.SettingRow {
            label: qsTr("Text size")
            Ui.Segmented {
                options: [{ label: "90%", value: 0.9 }, { label: "100%", value: 1.0 }, { label: "110%", value: 1.1 }, { label: "125%", value: 1.25 }]
                value: Theme.textScale
                onPicked: (v) => studio.set("appearance/textScale", v)
            }
        }
        Ui.SettingRow {
            label: qsTr("Font")
            hint: qsTr("Takes effect the next time f1int starts")
            ComboBox {
                id: fontBox
                width: 170
                implicitHeight: 32
                model: [qsTr("System"), "Segoe UI", "Arial", "Verdana", "Georgia", "Consolas"]
                currentIndex: Math.max(0, model.indexOf(studio.get("appearance/font", qsTr("System"))))
                onActivated: (i) => studio.set("appearance/font", i === 0 ? "" : model[i])
                background: Rectangle { radius: Theme.radius; color: Theme.field; border.width: 1; border.color: Theme.line }
                contentItem: Text { leftPadding: 12; text: fontBox.displayText; color: Theme.fg; font.pixelSize: Theme.px(13); verticalAlignment: Text.AlignVCenter }
                indicator: Icon { glyph: "down"; color: Theme.dim; sourceSize: Qt.size(14, 14); x: fontBox.width - width - 10; y: (fontBox.height - height) / 2 }
                popup.background: Rectangle { radius: Theme.cardRadius; color: Theme.surface; border.width: 1; border.color: Theme.line }
            }
        }
        Ui.SettingRow {
            label: qsTr("Headings")
            hint: qsTr("Page and section titles")
            Ui.Segmented {
                options: [{ label: qsTr("Plain"), value: "system" }, { label: qsTr("Dot-matrix"), value: "dot" }]
                value: Theme.headingStyle
                onPicked: (v) => studio.set("appearance/headingFont", v)
            }
        }
        Ui.SettingRow {
            label: qsTr("Dot-matrix numbers")
            hint: qsTr("Memory, counts and clock in f1int's dotted display face")
            last: true
            Ui.Toggle { checked: studio.get("appearance/dotNumbers", true); onToggled: studio.set("appearance/dotNumbers", checked) }
        }
    }

    // ---------- effects ----------
    IconsEditor { visible: studio.searching || studio.cat === "icons"; Layout.fillWidth: true }

    Ui.Section {
        visible: studio.searching || studio.cat === "icons"
        title: qsTr("Effects")
        Ui.SettingRow {
            label: qsTr("Animations")
            hint: Browser.reduceMotion ? qsTr("Off, because Windows' animation effects are off") : ""
            Ui.Segmented {
                options: [{ label: qsTr("Off"), value: "off" }, { label: qsTr("Quick"), value: "fast" }, { label: qsTr("Normal"), value: "normal" }, { label: qsTr("Relaxed"), value: "relaxed" }]
                value: Theme.motion
                onPicked: (v) => studio.set("appearance/motion", v)
            }
        }
        Ui.SettingRow {
            label: qsTr("Hover highlights")
            Ui.Toggle { checked: Theme.hoverEffects; onToggled: studio.set("appearance/hoverEffects", checked) }
        }
        Ui.SettingRow {
            visible: Qt.platform.os === "windows"
            label: qsTr("Frosted glass")
            hint: qsTr("Your wallpaper shows softly through the window")
            last: !Theme.glass
            Ui.Toggle { checked: Theme.glass; onToggled: studio.set("appearance/glass", checked) }
        }
        Ui.SettingRow {
            visible: Theme.glass
            label: qsTr("Glass tint")
            last: true
            Ui.Slide { width: 160; from: 0; to: 1; value: Theme.glassTint; onMoved: studio.set("appearance/glassTint", Math.round(value * 100) / 100) }
        }
    }
    Ui.Pill {
        visible: !studio.searching
        text: qsTr("Reset all appearance settings")
        onClicked: {
            for (const k of Theme.lookKeys) Browser.resetSetting(k)
            for (const k of Theme.presetKeys()) Browser.resetSetting(k)
        }
    }
}
