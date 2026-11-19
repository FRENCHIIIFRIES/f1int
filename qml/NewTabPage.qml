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
        background: { type: "none", color: "#000000", image: "", dim: 0.55, density: 22, opacity: 0.18,
                      colors: ["#1b1446", "#6e4aff"], angle: 160, pattern: "grid" },
        layout:     { order: ["status", "weather", "clock", "date", "search", "shortcuts", "bookmarks", "recent", "note", "todo"], spacing: 22 },
        clock:      { on: false,  pos: "center", size: "M", h24: true, seconds: false, dotFont: true, style: "" },
        date:       { on: false, pos: "center", size: "S" },
        search:     { on: true,  pos: "center", size: "M", autofocus: true },
        shortcuts:  { on: false, pos: "center", size: "M", items: [], layout: "row", shape: "circle" },
        bookmarks:  { on: false, pos: "bottom", size: "M", count: 8 },
        recent:     { on: false, pos: "bottom", size: "M", count: 6 },
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
    function scale(size) { return size === "S" ? 0.75 : size === "L" ? 1.45 : size === "XL" ? 1.9 : 1 }
    // Widgets in your order (older settings may lack newer widgets: they go at the end).
    readonly property var order: {
        const saved = cfg.layout.order.filter(w => defaults[w] !== undefined && w !== "background" && w !== "layout")
        return saved.concat(defaults.layout.order.filter(w => saved.indexOf(w) < 0))
    }
    property string dragging: ""   // the widget being dragged in the customise panel
    property int dropAt: -1
    readonly property string clockStyle: cfg.clock.style !== "" ? cfg.clock.style : cfg.clock.dotFont ? "dots" : "plain"
    readonly property var widgetComponents: ({ status: statusWidget, weather: weatherWidget, clock: clockWidget, date: dateWidget, search: searchWidget,
                                               shortcuts: shortcutsWidget, bookmarks: bookmarksWidget, recent: recentWidget, note: noteWidget, todo: todoWidget })
    function focusSearch() { if (searchLoader.item) searchLoader.item.focusField() }
    function openCustomise() { customise.visible = true }
    function openColorPicker() { bgColor.open() }
    function go(text) {
        const url = Browser.urlFromInput(text)
        if (view && url.toString() !== "") { view.url = url; view.forceActiveFocus() }
    }

    color: cfg.background.type === "solid" ? cfg.background.color : cfg.background.type === "none" ? "transparent" : Theme.bg

    // ---------- background ----------
    Image {
        anchors.fill: parent
        visible: page.cfg.background.type === "image" && page.cfg.background.image !== ""
        // Pictures live in f1int's checked asset store (older settings may hold a file address).
        source: visible ? (/^[0-9a-f]{20}\./.test(page.cfg.background.image) ? Browser.assets.url(page.cfg.background.image) : page.cfg.background.image) : ""
        sourceSize: Qt.size(page.width, page.height)   // decoded at screen size, not full camera size
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        Rectangle { anchors.fill: parent; color: "black"; opacity: page.cfg.background.dim }   // keeps text readable
    }
    Fill {
        anchors.fill: parent
        visible: page.cfg.background.type === "gradient" || page.cfg.background.type === "pattern"
        base: Theme.bg
        spec: Object.assign({}, Theme.fillDefaults, { type: page.cfg.background.type, colors: page.cfg.background.colors,
                             angle: page.cfg.background.angle, pattern: page.cfg.background.pattern, patternOpacity: page.cfg.background.opacity * 1.5 })
    }
    DotGrid {
        anchors.fill: parent
        visible: page.cfg.background.type === "dots"
        spacing: page.cfg.background.density
        dot: 2
        dotOpacity: page.cfg.background.opacity
    }

    readonly property color ink: cfg.background.type === "image" || cfg.background.type === "gradient" ? "#ffffff" : Theme.fg   // text colour on top

    // ---------- the three zones ----------
    component Zone: Column {
        id: zone
        property string pos
        spacing: page.cfg.layout.spacing
        Repeater {
            model: page.order.filter(w => page.cfg[w].on && page.cfg[w].pos === zone.pos)
            Loader {
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: page.widgetComponents[modelData]
                onLoaded: if (modelData === "search") searchLoader.item = item
            }
        }
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
                options: [{ label: "S", value: "S" }, { label: "M", value: "M" }, { label: "L", value: "L" }, { label: "XL", value: "XL" }]
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
        Item {
            id: clock
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
            readonly property bool analog: page.clockStyle === "analog"
            implicitWidth: analog ? face.width : digits.implicitWidth
            implicitHeight: analog ? face.height : digits.implicitHeight
            Text {
                id: digits
                visible: !clock.analog
                text: Qt.formatTime(clock.now, (page.cfg.clock.h24 ? "HH:mm" : "h:mm") + (page.cfg.clock.seconds ? ":ss" : "") + (page.cfg.clock.h24 ? "" : " AP"))
                color: page.ink
                font.family: page.clockStyle === "dots" ? "Doto" : Qt.application.font.family
                font.pixelSize: Theme.px((page.clockStyle === "thin" ? 76 : 64) * page.scale(page.cfg.clock.size))
                font.weight: page.clockStyle === "thin" ? Font.ExtraLight : Font.DemiBold
                font.letterSpacing: page.clockStyle === "thin" ? 2 : 0
            }
            Canvas {   // analogue: a dial of dots and three hands
                id: face
                visible: clock.analog
                width: 140 * page.scale(page.cfg.clock.size)
                height: width
                onVisibleChanged: requestPaint()
                Connections { target: clock; function onNowChanged() { if (clock.analog) face.requestPaint() } }
                onPaint: {
                    const c = getContext("2d"), r = width / 2
                    c.reset(); c.translate(r, r)
                    c.fillStyle = page.ink
                    for (let i = 0; i < 12; ++i) {
                        const a = i * Math.PI / 6
                        c.beginPath(); c.arc(Math.sin(a) * (r - 6), -Math.cos(a) * (r - 6), i % 3 === 0 ? 3 : 1.6, 0, 2 * Math.PI); c.fill()
                    }
                    const hand = (angle, len, w, colour) => {
                        c.save(); c.rotate(angle); c.strokeStyle = colour; c.lineWidth = w; c.lineCap = "round"
                        c.beginPath(); c.moveTo(0, 6); c.lineTo(0, -len); c.stroke(); c.restore()
                    }
                    const t = clock.now
                    hand((t.getHours() % 12 + t.getMinutes() / 60) * Math.PI / 6, r * 0.5, 4, page.ink)
                    hand((t.getMinutes() + t.getSeconds() / 60) * Math.PI / 30, r * 0.75, 3, page.ink)
                    if (page.cfg.clock.seconds) hand(t.getSeconds() * Math.PI / 30, r * 0.82, 1.5, Theme.accent)
                    c.fillStyle = Theme.accent; c.beginPath(); c.arc(0, 0, 4, 0, 2 * Math.PI); c.fill()
                }
            }
        }
    }
    Component {
        id: dateWidget
        Text {
            text: new Date().toLocaleDateString(Qt.locale(), "dddd d MMMM")
            color: page.ink
            opacity: 0.7
            font.pixelSize: Theme.px(14 * page.scale(page.cfg.date.size))
        }
    }
    Component {
        id: searchWidget
        Rectangle {
            function focusField() { field.forceActiveFocus() }
            width: 460 * page.scale(page.cfg.search.size)
            height: 40 * Math.sqrt(page.scale(page.cfg.search.size))
            radius: height / 2
            color: page.cfg.background.type === "solid" ? Theme.surface : Theme.field
            border.width: 1
            border.color: field.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55) : Theme.line
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
                font.pixelSize: Theme.px(14)
                onAccepted: page.go(text)
                Component.onCompleted: if (page.cfg.search.autofocus) Qt.callLater(forceActiveFocus)
            }
        }
    }
    Component {
        id: shortcutsWidget
        Grid {
            columns: page.cfg.shortcuts.layout === "grid" ? 4 : 8
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
                        radius: page.cfg.shortcuts.shape === "square" ? Math.min(width / 4, Theme.radius + 2) : width / 2
                        color: hover.hovered ? Theme.selected : "transparent"
                        border.width: 1
                        border.color: hover.hovered ? Theme.accent : Theme.line
                        HoverHandler { id: hover }
                        Image {   // the site's logo; its first letter until the logo arrives
                            id: tileIcon
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.46); height: width
                            sourceSize: Qt.size(64, 64)
                            source: { void Browser.favicons.revision; return Browser.favicons.icon(modelData.url) }
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !tileIcon.visible
                            text: (modelData.title || modelData.url.replace(/^https?:\/\/(www\.)?/, "")).charAt(0).toUpperCase()
                            color: page.ink
                            font.family: Theme.numberFont
                            font.pixelSize: Theme.px(22 * parent.parent.s)
                            font.weight: Font.DemiBold
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
                        font.pixelSize: Theme.px(12)
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
    // Your bookmarks, or the sites you visited last, as a wrap of chips.
    component LinkChips: Flow {
        id: chips
        property var items: []
        property real sizeScale: 1
        // As wide as its chips (so it sits centred), wrapping at most 620 px.
        width: Math.min((Math.min(620, page.width - 80)) * Math.sqrt(sizeScale),
                        items.reduce((sum, it) => sum + chipWidth(it) + spacing, 0) - spacing)
        function chipWidth(it) { return Math.min(220, fm.advanceWidth(it.title || String(it.url).replace(/^https?:\/\/(www\.)?/, "")) + 40) * Math.sqrt(sizeScale) }
        FontMetrics { id: fm; font.pixelSize: Theme.px(12) }   // measures without changing anything (no loops)
        spacing: 8
        Repeater {
            model: chips.items
            Rectangle {
                id: chip
                required property var modelData
                width: chips.chipWidth(chip.modelData)
                height: 34 * Math.sqrt(chips.sizeScale)
                radius: height / 2
                color: chipHover.hovered ? Theme.hover : Theme.field
                border.width: 1
                border.color: Theme.line
                HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                Accessible.role: Accessible.Link
                Accessible.name: chipText.text
                Image {
                    id: chipIcon
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; sourceSize: Qt.size(16, 16)
                    source: { void Browser.favicons.revision; return Browser.favicons.icon(chip.modelData.url) }
                    visible: status === Image.Ready && implicitWidth > 0
                }
                Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; glyph: "globe"; sourceSize: Qt.size(14, 14); color: Theme.dim; visible: !chipIcon.visible }
                Text {
                    id: chipText
                    x: 30; width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.title || String(chip.modelData.url).replace(/^https?:\/\/(www\.)?/, "")
                    color: page.ink
                    font.pixelSize: Theme.px(12)
                    elide: Text.ElideRight
                }
                MouseArea { anchors.fill: parent; onClicked: page.go(String(chip.modelData.url)) }
            }
        }
    }
    Component {
        id: bookmarksWidget
        LinkChips { sizeScale: page.scale(page.cfg.bookmarks.size); items: { void Browser.library.revision; return Browser.library.bookmarks().slice(0, page.cfg.bookmarks.count) } }
    }
    Component {
        id: recentWidget   // (never in incognito)
        LinkChips { sizeScale: page.scale(page.cfg.recent.size); items: { void Browser.library.revision; return page.incognito ? [] : Browser.library.history("", page.cfg.recent.count) } }
    }
    Component {
        id: noteWidget
        Rectangle {
            width: 360 * page.scale(page.cfg.note.size)
            height: 120 * page.scale(page.cfg.note.size)
            radius: 14
            color: page.cfg.background.type === "solid" ? Theme.surface : Theme.field
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
                font.pixelSize: Theme.px(13)
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
            color: page.cfg.background.type === "solid" ? Theme.surface : Theme.field
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
                            Icon { anchors.centerIn: parent; visible: modelData.done; glyph: "check"; sourceSize: Qt.size(12, 12); color: Theme.textOnAccent }
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
                            font.pixelSize: Theme.px(13)
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
                    font.pixelSize: Theme.px(13)
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
            Icon {   // charging: a monochrome bolt (not a colour emoji)
                visible: parent.battery.percent >= 0 && parent.battery.charging
                glyph: "bolt"
                color: page.ink
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: parent.battery.percent >= 0
                text: parent.battery.percent + "%"
                color: page.ink
                font.family: Theme.numberFont
                font.pixelSize: Theme.px(20 * page.scale(page.cfg.status.size))
                font.weight: Font.Bold
            }
            Text {
                text: Math.round((parent.info.total || 0) / 1048576) + " MB"
                color: page.ink
                font.family: Theme.numberFont
                font.pixelSize: Theme.px(20 * page.scale(page.cfg.status.size))
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
            font.family: Theme.numberFont
            font.pixelSize: Theme.px(20 * page.scale(page.cfg.weather.size))
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
                        reading = Math.round(w.current.temperature_2m) + "°" + (f ? "F" : "C") + "  " + r.name
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
        onAccepted: {
            const r = Browser.assets.add(selectedFile, "image")   // checked and copied into f1int
            if (!r.ok) { arrangeMessage.text = r.error; return }
            page.set("background", "image", r.id); page.set("background", "type", "image")
        }
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
                    Ui.Heading { text: qsTr("Customise"); font.pixelSize: Theme.px(22) }
                    Item { Layout.fillWidth: true }
                    IconButton { iconName: "close"; onClicked: customise.visible = false }
                }

                Ui.Section {
                    title: qsTr("Background")
                    Ui.SettingRow {
                        label: qsTr("Style")
                        Ui.Segmented {
                            options: [{ label: qsTr("Clear"), value: "none" }, { label: qsTr("Dots"), value: "dots" }, { label: qsTr("Solid"), value: "solid" },
                                      { label: qsTr("Gradient"), value: "gradient" }, { label: qsTr("Pattern"), value: "pattern" }, { label: qsTr("Picture"), value: "image" }]
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
                        Ui.Slide { width: 140; from: 0; to: 0.9; value: page.cfg.background.dim; onMoved: page.set("background", "dim", value) }
                    }
                    Ui.SettingRow {
                        visible: page.cfg.background.type === "solid"
                        label: qsTr("Colour")
                        Ui.Pill { text: page.cfg.background.color; onClicked: bgColor.open() }
                    }
                    Ui.SettingRow {
                        visible: page.cfg.background.type === "gradient"
                        label: qsTr("Colours")
                        Row {
                            spacing: 6
                            Repeater {
                                model: page.cfg.background.colors
                                Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: 28; height: 28; radius: 14; color: modelData
                                    border.width: 1; border.color: Theme.line
                                    Accessible.role: Accessible.Button
                                    Accessible.name: qsTr("Gradient colour %1").arg(index + 1)
                                    MouseArea { anchors.fill: parent; onClicked: { bgColor.target = parent.index; bgColor.open() } }
                                }
                            }
                        }
                    }
                    Ui.SettingRow {
                        visible: page.cfg.background.type === "gradient"
                        label: qsTr("Direction")
                        Ui.Slide { width: 140; from: 0; to: 360; stepSize: 5; value: page.cfg.background.angle; onMoved: page.set("background", "angle", value) }
                    }
                    Ui.SettingRow {
                        visible: page.cfg.background.type === "pattern"
                        label: qsTr("Pattern")
                        Ui.Segmented {
                            options: [{ label: qsTr("Grid"), value: "grid" }, { label: qsTr("Lines"), value: "lines" }, { label: qsTr("Diagonal"), value: "diagonal" },
                                      { label: qsTr("Waves"), value: "waves" }, { label: qsTr("Cross"), value: "cross" }]
                            value: page.cfg.background.pattern
                            onPicked: (v) => page.set("background", "pattern", v)
                        }
                    }
                    Ui.SettingRow {
                        visible: page.cfg.background.type === "dots"
                        label: qsTr("Dot spacing")
                        Ui.Slide { width: 140; from: 10; to: 48; value: page.cfg.background.density; onMoved: page.set("background", "density", Math.round(value)) }
                    }
                    Ui.SettingRow {
                        visible: page.cfg.background.type === "dots" || page.cfg.background.type === "pattern"
                        label: qsTr("Strength")
                        last: true
                        Ui.Slide { width: 140; from: 0.04; to: 0.6; value: page.cfg.background.opacity; onMoved: page.set("background", "opacity", value) }
                    }
                }

                Ui.Section {
                    title: qsTr("Widgets: drag to reorder; place, size, on/off")
                    Repeater {
                        model: page.order
                        Item {
                            id: slot
                            required property string modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: widgetRow.implicitHeight
                            DropArea {   // where a dragged widget would land (saved when you let go)
                                anchors.fill: parent
                                onEntered: page.dropAt = slot.index
                            }
                            Rectangle {   // the landing line
                                visible: page.dropAt === slot.index && page.dragging !== "" && page.dragging !== slot.modelData
                                width: parent.width; height: 2; radius: 1
                                color: Theme.accent
                                z: 5
                            }
                        Rectangle {   // the grip: drag it up or down (beside the row, moving with it)
                                x: widgetRow.x + 3
                                y: widgetRow.y + (widgetRow.height - height) / 2
                                z: 3
                                width: 10; height: 22
                                color: "transparent"
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Repeater { model: 3; Rectangle { width: 6; height: 1.5; radius: 1; color: Theme.dim } }
                                }
                                MouseArea {
                                    id: grip
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.SizeVerCursor
                                    drag.target: widgetRow
                                    drag.axis: Drag.YAxis
                                    onPressed: page.dragging = slot.modelData
                                    onReleased: {
                                        widgetRow.y = 0
                                        const o = page.order.slice(), from = o.indexOf(page.dragging), to = page.dropAt
                                        page.dragging = ""; page.dropAt = -1
                                        if (from < 0 || to < 0 || from === to) return
                                        o.splice(from, 1); o.splice(to, 0, slot.modelData)
                                        page.set("layout", "order", o)
                                    }
                                }
                                Accessible.role: Accessible.Grip
                                Accessible.name: qsTr("Drag to reorder")
                            }
                            WidgetRow {
                                id: widgetRow
                                width: slot.width
                                widget: slot.modelData
                                label: ({ clock: qsTr("Clock"), date: qsTr("Date"), search: qsTr("Search bar"), shortcuts: qsTr("Shortcuts"),
                                          bookmarks: qsTr("Bookmarks"), recent: qsTr("Recently visited"), note: qsTr("Note"), todo: qsTr("To-do list"),
                                          status: qsTr("Battery and RAM"), weather: qsTr("Weather") })[slot.modelData]
                                hint: slot.modelData === "weather" ? qsTr("Uses the internet (open-meteo.com)") : ""
                                last: slot.index === page.order.length - 1
                                Drag.active: grip.drag.active
                                Drag.source: widgetRow
                                Drag.hotSpot.y: height / 2
                            }
                        }
                    }
                }
                Ui.Section {
                    title: qsTr("Layout")
                    Ui.SettingRow {
                        label: qsTr("Space between widgets")
                        last: true
                        Ui.Slide { width: 140; from: 6; to: 60; value: page.cfg.layout.spacing; onMoved: page.set("layout", "spacing", Math.round(value)) }
                    }
                }
                Text { id: arrangeMessage; visible: text !== ""; color: Theme.accent2; font.pixelSize: Theme.px(12) }

                Ui.Section {
                    title: qsTr("Clock and search")
                    Ui.SettingRow { label: qsTr("24-hour clock"); Ui.Toggle { checked: page.cfg.clock.h24; onToggled: page.set("clock", "h24", checked) } }
                    Ui.SettingRow { label: qsTr("Show seconds"); Ui.Toggle { checked: page.cfg.clock.seconds; onToggled: page.set("clock", "seconds", checked) } }
                    Ui.SettingRow {
                        label: qsTr("Clock style")
                        Ui.Segmented {
                            options: [{ label: qsTr("Dot-matrix"), value: "dots" }, { label: qsTr("Plain"), value: "plain" },
                                      { label: qsTr("Thin"), value: "thin" }, { label: qsTr("Analogue"), value: "analog" }]
                            value: page.clockStyle
                            onPicked: (v) => page.set("clock", "style", v)
                        }
                    }
                    Ui.SettingRow { label: qsTr("Focus search bar automatically"); last: true; Ui.Toggle { checked: page.cfg.search.autofocus; onToggled: page.set("search", "autofocus", checked) } }
                }

                Ui.Section {
                    title: qsTr("Shortcuts (up to 8)")
                    Ui.SettingRow {
                        label: qsTr("Layout")
                        Row {
                            spacing: 6
                            Ui.Segmented { options: [{ label: qsTr("Row"), value: "row" }, { label: qsTr("Grid"), value: "grid" }]; value: page.cfg.shortcuts.layout; onPicked: (v) => page.set("shortcuts", "layout", v) }
                            Ui.Segmented { options: [{ label: qsTr("Round"), value: "circle" }, { label: qsTr("Square"), value: "square" }]; value: page.cfg.shortcuts.shape; onPicked: (v) => page.set("shortcuts", "shape", v) }
                        }
                    }
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
        property int target: -1          // -1 = the solid colour, 0.. = a gradient colour
        onClosed: target = -1
        contentItem: ColorWheel {
            color: bgColor.target >= 0 ? page.cfg.background.colors[bgColor.target] : page.cfg.background.color
            onPicked: (c) => {
                if (bgColor.target >= 0) { const l = page.cfg.background.colors.slice(); l[bgColor.target] = c.toString(); page.set("background", "colors", l) }
                else page.set("background", "color", c.toString())
                bgColor.close()
            }
        }
    }
}
