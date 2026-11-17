import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import QtWebEngine
import f1int

// The new tab page. Built in QML (not a web page), so an empty tab costs almost no RAM.
// Mostly empty by default: dot grid, small dot-matrix clock, thin search bar.
// Every widget can be turned on/off, placed top/centre/bottom and sized S/M/L
// from the customise panel (the dot button that appears in the corner on hover).
// Widgets that are off aren't created at all.
Rectangle {
    id: page
    property WebEngineView view: null
    property bool incognito: false

    // ---------- settings (one JSON value, so it can be exported/imported as a whole) ----------
    readonly property var defaults: ({
        background: { type: "dots", color: "#000000", image: "", dim: 0.55, density: 22, opacity: 0.18 },
        clock:      { on: true,  pos: "center", size: "M", h24: true, seconds: false, dotFont: true },
        date:       { on: false, pos: "center", size: "S" },
        search:     { on: true,  pos: "center", size: "M", autofocus: true },
        shortcuts:  { on: false, pos: "center", size: "M", items: [] },
        note:       { on: false, pos: "bottom", size: "M" },
        todo:       { on: false, pos: "bottom", size: "M", items: [] },
        status:     { on: false, pos: "top",    size: "S" },
        weather:    { on: false, pos: "top",    size: "S", city: "", unit: "C" }
    })
    readonly property var cfg: {
        void Browser.settingsRevision
        let saved = {}
        try { saved = JSON.parse(Browser.setting("newtab/config", "{}")) } catch (e) {}
        const out = {}
        for (const k in defaults) out[k] = Object.assign({}, defaults[k], saved[k] || {})
        return out
    }
    function set(widget, key, value) {
        const c = JSON.parse(JSON.stringify(cfg))
        c[widget][key] = value
        Browser.setSetting("newtab/config", JSON.stringify(c))
    }
    function scale(size) { return size === "S" ? 0.75 : size === "L" ? 1.45 : 1 }
    function focusSearch() { if (searchLoader.item) searchLoader.item.focusField() }
    function openCustomise() { customise.visible = true }
    function openColorPicker() { bgColor.open() }
    function go(text) {
        const url = Browser.urlFromInput(text)
        if (view && url.toString() !== "") { view.url = url; view.forceActiveFocus() }
    }

    color: cfg.background.type === "solid" ? cfg.background.color : Theme.bg

    // ---------- background ----------
    Image {
        anchors.fill: parent
        visible: page.cfg.background.type === "image" && page.cfg.background.image !== ""
        source: visible ? page.cfg.background.image : ""
        sourceSize: Qt.size(page.width, page.height)   // decoded at screen size, not full camera size
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        Rectangle { anchors.fill: parent; color: "black"; opacity: page.cfg.background.dim }   // keeps text readable
    }
    DotGrid {
        anchors.fill: parent
        visible: page.cfg.background.type === "dots"
        spacing: page.cfg.background.density
        dot: 2
        dotOpacity: page.cfg.background.opacity
    }

    readonly property color ink: cfg.background.type === "image" ? "#ffffff" : Theme.fg   // text colour on top

    // ---------- the three zones ----------
    component Zone: Column {
        property string pos
        spacing: 22
        Loader { active: page.cfg.status.on && page.cfg.status.pos === parent.pos; anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: statusWidget }
        Loader { active: page.cfg.weather.on && page.cfg.weather.pos === parent.pos; anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: weatherWidget }
        Loader { active: page.cfg.clock.on && page.cfg.clock.pos === parent.pos; anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: clockWidget }
        Loader { active: page.cfg.date.on && page.cfg.date.pos === parent.pos; anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: dateWidget }
        Loader {
            id: zoneSearch
            active: page.cfg.search.on && page.cfg.search.pos === parent.pos
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: searchWidget
            onLoaded: { searchLoader.item = item }
        }
        Loader { active: page.cfg.shortcuts.on && page.cfg.shortcuts.pos === parent.pos; anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: shortcutsWidget }
        Loader { active: page.cfg.note.on && page.cfg.note.pos === parent.pos; anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: noteWidget }
        Loader { active: page.cfg.todo.on && page.cfg.todo.pos === parent.pos; anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: todoWidget }
    }
    QtObject { id: searchLoader; property var item: null }

    // One widget line in the customise panel: place, size, on/off.
    component WidgetRow: Ui.SettingRow {
        property string widget
        label: ""
        Row {
            spacing: 6
            Ui.Segmented {
                visible: page.cfg[widget].on
                options: [{ label: "↑", value: "top" }, { label: "•", value: "center" }, { label: "↓", value: "bottom" }]
                value: page.cfg[widget].pos
                onPicked: (v) => page.set(widget, "pos", v)
            }
            Ui.Segmented {
                visible: page.cfg[widget].on
                options: [{ label: "S", value: "S" }, { label: "M", value: "M" }, { label: "L", value: "L" }]
                value: page.cfg[widget].size
                onPicked: (v) => page.set(widget, "size", v)
            }
            Ui.Toggle { checked: page.cfg[widget].on; onToggled: page.set(widget, "on", checked) }
        }
    }


    // Top, centre and bottom groups, stacked so a crowded page pushes them apart instead of overlapping.
    Flickable {
        anchors.fill: parent
        contentHeight: Math.max(height, zones.implicitHeight + 96)
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: zones
            width: parent.width
            height: Math.max(implicitHeight, page.height - 96)
            y: 48
            spacing: 28
            Zone { pos: "top"; Layout.alignment: Qt.AlignHCenter }
            Item { Layout.fillHeight: true }
            Zone { pos: "center"; Layout.alignment: Qt.AlignHCenter }
            Item { Layout.fillHeight: true }
            Zone { pos: "bottom"; Layout.alignment: Qt.AlignHCenter }
        }
    }

    // ---------- widgets ----------
    Component {
        id: clockWidget
        Text {
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.now = new Date() }
            text: Qt.formatTime(now, (page.cfg.clock.h24 ? "HH:mm" : "h:mm") + (page.cfg.clock.seconds ? ":ss" : "") + (page.cfg.clock.h24 ? "" : " AP"))
            color: page.ink
            font.family: page.cfg.clock.dotFont ? Theme.dotFont : "Consolas, Menlo, monospace"
            font.pixelSize: 64 * page.scale(page.cfg.clock.size)
            font.weight: Font.Black
        }
    }
    Component {
        id: dateWidget
        Text {
            text: new Date().toLocaleDateString(Qt.locale(), "dddd d MMMM").toUpperCase()
            color: page.ink
            opacity: 0.7
            font.pixelSize: 13 * page.scale(page.cfg.date.size)
            font.letterSpacing: 2
        }
    }
    Component {
        id: searchWidget
        Rectangle {
            function focusField() { field.forceActiveFocus() }
            width: 460 * page.scale(page.cfg.search.size)
            height: 40 * Math.sqrt(page.scale(page.cfg.search.size))
            radius: height / 2
            color: page.cfg.background.type === "image" ? "#66000000" : Theme.surface
            border.width: 1
            border.color: field.activeFocus ? Theme.accent : Theme.line
            Icon { x: 16; anchors.verticalCenter: parent.verticalCenter; glyph: "search"; color: Theme.dim }
            TextField {
                id: field
                anchors.fill: parent
                leftPadding: 42
                rightPadding: 16
                background: null
                color: page.ink
                placeholderText: qsTr("Search %1 or type an address").arg(Browser.searchEngines.find(e => e.template === Browser.setting("search/template", "https://www.google.com/search?q=%s"))?.name ?? "")
                placeholderTextColor: Theme.dim
                selectionColor: Theme.accent
                font.pixelSize: 14
                onAccepted: page.go(text)
                Component.onCompleted: if (page.cfg.search.autofocus) Qt.callLater(forceActiveFocus)
            }
        }
    }
    Component {
        id: shortcutsWidget
        Row {
            spacing: 14 * page.scale(page.cfg.shortcuts.size)
            Repeater {
                model: page.cfg.shortcuts.items.slice(0, 8)
                Column {
                    required property var modelData
                    required property int index
                    spacing: 6
                    readonly property real s: page.scale(page.cfg.shortcuts.size)
                    Rectangle {   // monochrome tile: first letter in dot-matrix
                        width: 46 * parent.s
                        height: 46 * parent.s
                        radius: width / 2
                        color: hover.hovered ? Theme.selected : "transparent"
                        border.width: 1
                        border.color: hover.hovered ? Theme.accent : Theme.line
                        HoverHandler { id: hover }
                        Text {
                            anchors.centerIn: parent
                            text: (modelData.title || modelData.url.replace(/^https?:\/\/(www\.)?/, "")).charAt(0).toUpperCase()
                            color: page.ink
                            font.family: Theme.dotFont
                            font.pixelSize: 22 * parent.parent.s
                            font.weight: Font.Black
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (m) => {
                                if (m.button === Qt.RightButton) {   // right-click removes it
                                    const items = page.cfg.shortcuts.items.slice(); items.splice(index, 1)
                                    page.set("shortcuts", "items", items)
                                } else page.go(modelData.url)
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64 * parent.s
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.title
                        color: page.ink
                        opacity: 0.7
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
    Component {
        id: noteWidget
        Rectangle {
            width: 360 * page.scale(page.cfg.note.size)
            height: 120 * page.scale(page.cfg.note.size)
            radius: 14
            color: page.cfg.background.type === "image" ? "#66000000" : Theme.surface
            border.width: 1
            border.color: Theme.line
            TextArea {
                anchors.fill: parent
                anchors.margins: 6
                text: Browser.setting("newtab/note", "")
                placeholderText: qsTr("Note…")
                placeholderTextColor: Theme.dim
                color: page.ink
                wrapMode: TextArea.Wrap
                background: null
                font.pixelSize: 13
                onTextChanged: saveNote.restart()
                Timer { id: saveNote; interval: 600; onTriggered: Browser.setSetting("newtab/note", parent.text) }
            }
        }
    }
    Component {
        id: todoWidget
        Rectangle {
            width: 340 * page.scale(page.cfg.todo.size)
            height: todoColumn.implicitHeight + 24
            radius: 14
            color: page.cfg.background.type === "image" ? "#66000000" : Theme.surface
            border.width: 1
            border.color: Theme.line
            Column {
                id: todoColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6
                Repeater {
                    model: page.cfg.todo.items
                    Row {
                        required property var modelData
                        required property int index
                        spacing: 10
                        Rectangle {   // tick box
                            width: 16; height: 16; radius: 4
                            color: modelData.done ? Theme.accent : "transparent"
                            border.width: 1; border.color: modelData.done ? Theme.accent : Theme.dim
                            Icon { anchors.centerIn: parent; visible: modelData.done; glyph: "check"; sourceSize: Qt.size(12, 12); color: Theme.onAccent }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    const items = JSON.parse(JSON.stringify(page.cfg.todo.items))
                                    items[index].done = !items[index].done
                                    page.set("todo", "items", items)
                                }
                            }
                        }
                        Text {
                            text: modelData.text
                            color: page.ink
                            opacity: modelData.done ? 0.4 : 1
                            font.strikeout: modelData.done
                            font.pixelSize: 13
                            width: 260
                            elide: Text.ElideRight
                            MouseArea {   // right-click deletes
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onClicked: { const items = page.cfg.todo.items.slice(); items.splice(index, 1); page.set("todo", "items", items) }
                            }
                        }
                    }
                }
                TextField {
                    width: parent.width
                    placeholderText: qsTr("+ Add a to-do")
                    placeholderTextColor: Theme.dim
                    color: page.ink
                    background: null
                    font.pixelSize: 13
                    onAccepted: {
                        if (text.trim() === "") return
                        page.set("todo", "items", page.cfg.todo.items.concat([{ text: text.trim(), done: false }]))
                        text = ""
                    }
                }
            }
        }
    }
    Component {
        id: statusWidget   // battery and RAM
        Row {
            spacing: 20
            property var info: ({})
            property var battery: ({ percent: -1 })
            function refresh() { info = Browser.memoryInfo(); battery = Browser.battery() }
            Component.onCompleted: refresh()
            Timer { interval: 5000; running: true; repeat: true; onTriggered: parent.refresh() }
            Text {
                visible: parent.battery.percent >= 0
                text: (parent.battery.charging ? "⚡" : "") + parent.battery.percent + "%"
                color: page.ink
                font.family: Theme.dotFont
                font.pixelSize: 20 * page.scale(page.cfg.status.size)
                font.weight: Font.Bold
            }
            Text {
                text: Math.round((parent.info.total || 0) / 1048576) + " MB"
                color: page.ink
                font.family: Theme.dotFont
                font.pixelSize: 20 * page.scale(page.cfg.status.size)
                font.weight: Font.Bold
            }
        }
    }
    Component {
        id: weatherWidget   // uses open-meteo.com (free, no account); only when turned on
        Text {
            id: weather
            property string reading: page.cfg.weather.city === "" ? qsTr("Set a city in Customise") : "…"
            text: reading
            color: page.ink
            font.family: Theme.dotFont
            font.pixelSize: 20 * page.scale(page.cfg.weather.size)
            font.weight: Font.Bold
            function get(url, done) {
                const x = new XMLHttpRequest()
                x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE && x.status === 200) done(JSON.parse(x.responseText)) }
                x.open("GET", url); x.send()
            }
            Component.onCompleted: {
                const city = page.cfg.weather.city
                if (city === "") return
                get("https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(city), (g) => {
                    if (!g.results || !g.results.length) { reading = qsTr("City not found"); return }
                    const r = g.results[0], f = page.cfg.weather.unit === "F"
                    get("https://api.open-meteo.com/v1/forecast?current=temperature_2m&latitude=" + r.latitude + "&longitude=" + r.longitude
                        + (f ? "&temperature_unit=fahrenheit" : ""), (w) => {
                        reading = Math.round(w.current.temperature_2m) + "°" + (f ? "F" : "C") + "  " + r.name.toUpperCase()
                    })
                })
            }
        }
    }

    // ---------- customise button (a dot, only on hover) and panel ----------
    HoverHandler { id: pageHover }
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 18
        width: 34
        height: 34
        radius: 17
        color: Theme.surface
        border.width: 1
        border.color: Theme.line
        opacity: pageHover.hovered || customise.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Customise new tab page")
        Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.accent }
        ToolTip.visible: customiseHover.hovered
        ToolTip.text: qsTr("Customise")
        HoverHandler { id: customiseHover }
        MouseArea { anchors.fill: parent; onClicked: customise.visible = !customise.visible }
    }

    FileDialog {
        id: imageDialog
        nameFilters: [qsTr("Images (*.jpg *.jpeg *.png *.webp *.bmp)")]
        onAccepted: { page.set("background", "image", selectedFile.toString()); page.set("background", "type", "image") }
    }

    Rectangle {
        id: customise
        visible: false
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 12
        anchors.bottomMargin: 62
        width: 440
        radius: 16
        color: Theme.surface
        border.width: 1
        border.color: Theme.line

        Flickable {
            anchors.fill: parent
            anchors.margins: 14
            contentHeight: options.implicitHeight
            clip: true
            ScrollBar.vertical: ScrollBar { width: 4 }
            ColumnLayout {
                id: options
                width: parent.width
                spacing: 18
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("CUSTOMISE"); color: Theme.fg; font.family: Theme.dotFont; font.pixelSize: 22; font.weight: Font.Black }
                    Item { Layout.fillWidth: true }
                    IconButton { iconName: "close"; onClicked: customise.visible = false }
                }

                Ui.Section {
                    title: qsTr("Background")
                    Ui.SettingRow {
                        label: qsTr("Style")
                        Ui.Segmented {
                            options: [{ label: qsTr("Dots"), value: "dots" }, { label: qsTr("Solid"), value: "solid" }, { label: qsTr("Picture"), value: "image" }]
                            value: page.cfg.background.type
                            onPicked: (v) => v === "image" && page.cfg.background.image === "" ? imageDialog.open() : page.set("background", "type", v)
                        }
                    }
                    Ui.SettingRow {
                        visible: page.cfg.background.type === "image"
                        label: qsTr("Picture")
                        Ui.Pill { text: qsTr("Choose…"); onClicked: imageDialog.open() }
                    }
                    Ui.SettingRow {
                        visible: page.cfg.background.type === "image"
                        label: qsTr("Dim picture")
                        Slider { width: 140; from: 0; to: 0.9; value: page.cfg.background.dim; onMoved: page.set("background", "dim", value) }
                    }
                    Ui.SettingRow {
                        visible: page.cfg.background.type === "solid"
                        label: qsTr("Colour")
                        Ui.Pill { text: page.cfg.background.color; onClicked: bgColor.open() }
                    }
                    Ui.SettingRow {
                        visible: page.cfg.background.type === "dots"
                        label: qsTr("Dot spacing")
                        Slider { width: 140; from: 10; to: 48; value: page.cfg.background.density; onMoved: page.set("background", "density", Math.round(value)) }
                    }
                    Ui.SettingRow {
                        visible: page.cfg.background.type === "dots"
                        label: qsTr("Dot strength")
                        last: true
                        Slider { width: 140; from: 0.04; to: 0.6; value: page.cfg.background.opacity; onMoved: page.set("background", "opacity", value) }
                    }
                }

                Ui.Section {
                    title: qsTr("Widgets: place ↑ • ↓, size, on/off")
                    WidgetRow { widget: "clock"; label: qsTr("Clock") }
                    WidgetRow { widget: "date"; label: qsTr("Date") }
                    WidgetRow { widget: "search"; label: qsTr("Search bar") }
                    WidgetRow { widget: "shortcuts"; label: qsTr("Shortcuts") }
                    WidgetRow { widget: "note"; label: qsTr("Note") }
                    WidgetRow { widget: "todo"; label: qsTr("To-do list") }
                    WidgetRow { widget: "status"; label: qsTr("Battery and RAM") }
                    WidgetRow { widget: "weather"; label: qsTr("Weather"); hint: qsTr("Uses the internet (open-meteo.com)"); last: true }
                }

                Ui.Section {
                    title: qsTr("Clock and search")
                    Ui.SettingRow { label: qsTr("24-hour clock"); Ui.Toggle { checked: page.cfg.clock.h24; onToggled: page.set("clock", "h24", checked) } }
                    Ui.SettingRow { label: qsTr("Show seconds"); Ui.Toggle { checked: page.cfg.clock.seconds; onToggled: page.set("clock", "seconds", checked) } }
                    Ui.SettingRow { label: qsTr("Dot-matrix clock font"); Ui.Toggle { checked: page.cfg.clock.dotFont; onToggled: page.set("clock", "dotFont", checked) } }
                    Ui.SettingRow { label: qsTr("Focus search bar automatically"); last: true; Ui.Toggle { checked: page.cfg.search.autofocus; onToggled: page.set("search", "autofocus", checked) } }
                }

                Ui.Section {
                    title: qsTr("Shortcuts (up to 8)")
                    Ui.SettingRow {
                        label: qsTr("Add a site")
                        hint: qsTr("Right-click a shortcut to remove it")
                        last: true
                        Ui.Field {
                            width: 150
                            placeholderText: "example.com"
                            onAccepted: {
                                const url = Browser.urlFromInput(text)
                                if (url.toString() === "" || page.cfg.shortcuts.items.length >= 8) return
                                const title = url.toString().replace(/^https?:\/\/(www\.)?/, "").split(/[./]/)[0]
                                page.set("shortcuts", "items", page.cfg.shortcuts.items.concat([{ title: title, url: url.toString() }]))
                                page.set("shortcuts", "on", true)
                                text = ""
                            }
                        }
                    }
                }

                Ui.Section {
                    title: qsTr("Weather")
                    Ui.SettingRow {
                        label: qsTr("City")
                        Ui.Field { width: 150; text: page.cfg.weather.city; onEditingFinished: page.set("weather", "city", text.trim()) }
                    }
                    Ui.SettingRow {
                        label: qsTr("Unit")
                        last: true
                        Ui.Segmented {
                            options: [{ label: "°C", value: "C" }, { label: "°F", value: "F" }]
                            value: page.cfg.weather.unit
                            onPicked: (v) => page.set("weather", "unit", v)
                        }
                    }
                }

                Ui.Pill {
                    text: qsTr("Reset new tab page")
                    onClicked: Browser.setSetting("newtab/config", "{}")
                }
            }
        }
    }

    Popup {
        id: bgColor
        anchors.centerIn: parent
        width: 260
        padding: 18
        modal: true
        background: Rectangle { color: Theme.surface; radius: 16; border.width: 1; border.color: Theme.line }
        contentItem: ColorWheel {
            color: page.cfg.background.color
            onPicked: (c) => { page.set("background", "color", c.toString()); bgColor.close() }
        }
    }
}
