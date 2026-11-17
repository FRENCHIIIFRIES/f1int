import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Particles
import f1int

// First-run welcome: a short animated intro, then bring bookmarks, history and passwords
// over from another browser, pick a look and a search engine. Shown once; the main menu
// has "Welcome tour" to see it again. With reduced motion it only fades.
Rectangle {
    id: welcome
    signal finished()
    property int step: 0
    readonly property int steps: 5
    readonly property bool still: Theme.anim === 0
    readonly property int slow: still ? 0 : 420
    readonly property string mod: Qt.platform.os === "osx" ? "⌘" : "Ctrl"

    color: Theme.bg
    focus: true
    Keys.onEscapePressed: finish()
    Keys.onLeftPressed: back()
    Keys.onRightPressed: next()

    function next() { if (step < steps - 1) step++; else finish() }
    function back() { if (step > 0) step-- }
    function finish() { Browser.setSetting("welcome/done", true); finished() }
    function sparkAt(item, fx, fy, count) {   // a burst of sparks from a point on an item (fx, fy: 0..1)
        if (still) return
        const p = item.mapToItem(welcome, item.width * fx, item.height * fy)
        sparks.burst(count, p.x, p.y)
    }
    function spark(count) { sparkAt(logo, 0.68, 0.62, count) }   // where the steel meets the flint

    // Keep clicks, scrolls and hovers away from the browser underneath.
    MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: (w) => w.accepted = true }

    // Slowly drifting dots in the background (one dot spacing per loop, so it never jumps).
    DotGrid {
        id: dots
        width: parent.width + spacing * 2
        height: parent.height + spacing * 2
        dotOpacity: 0.07
        NumberAnimation on x { from: 0; to: -dots.spacing; duration: 2600; loops: Animation.Infinite; running: !welcome.still }
        NumberAnimation on y { from: 0; to: -dots.spacing; duration: 3900; loops: Animation.Infinite; running: !welcome.still }
    }

    // Sparks: shared by the intro and the last page.
    ParticleSystem { id: particles; anchors.fill: parent; running: !welcome.still }
    ImageParticle {
        system: particles
        source: "qrc:///particleresources/glowdot.png"
        color: Qt.lighter(Theme.accent, 1.5)
        colorVariation: 0.08
        alpha: 0.9
        entryEffect: ImageParticle.Fade
    }
    Emitter {
        id: sparks
        system: particles
        enabled: false
        lifeSpan: 900
        lifeSpanVariation: 300
        size: 9
        sizeVariation: 5
        endSize: 1
        velocity: AngleDirection { angle: -40; angleVariation: 80; magnitude: 260; magnitudeVariation: 140 }
    }
    Gravity { system: particles; angle: 90; magnitude: 520 }

    // ---------- top bar: the name, and a way out ----------
    RowLayout {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 }
        Image { source: "qrc:/logo/f1int.svg"; sourceSize: Qt.size(22, 22); opacity: welcome.step > 0 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.anim } } }
        Text { text: "f1int"; color: Theme.fg; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; opacity: welcome.step > 0 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.anim } } }
        Item { Layout.fillWidth: true }
        Ui.Pill { text: qsTr("Skip intro"); visible: welcome.step < welcome.steps - 1; onClicked: welcome.finish() }
    }

    // ---------- the pages ----------
    // Each page slides in from the side it comes from and fades.
    component Page: Item {
        required property int index
        readonly property Item host: parent ? parent.parent : null   // the welcome screen (ids outside aren't visible here)
        readonly property int at: host ? host.step : 0
        readonly property bool current: at === index
        readonly property int slow: host ? host.slow : 0
        width: host ? Math.min(640, host.width - 48) : 0
        height: host ? host.height - y - 100 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: host ? Math.max(80, (host.height - 600) / 2) : 80    // a little lower on tall windows
        opacity: current ? 1 : 0
        visible: opacity > 0
        transform: Translate {
            x: slow === 0 ? 0 : (index - at) * 70
            Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
    }

    Item {
        id: pages
        anchors.fill: parent

        // 1. Hello: the logo strikes a spark, then the name and three promises rise in.
        Page {
            index: 0
            Rectangle {   // soft glow behind the logo
                id: glow
                anchors.centerIn: logo
                width: 260; height: 260; radius: 130
                color: Theme.accent
                opacity: 0
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64 }
                SequentialAnimation on opacity {
                    running: !welcome.still && welcome.step === 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.22; duration: 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.08; duration: 1800; easing.type: Easing.InOutSine }
                }
            }
            Image {
                id: logo
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(10, (parent.height - 400) / 2)
                width: 140; height: 140
                sourceSize: Qt.size(280, 280)
                source: "qrc:/logo/f1int.svg"
                scale: welcome.still ? 1 : 0.4
                opacity: welcome.still ? 1 : 0
            }
            Text {
                id: hello
                transform: Translate { id: helloRise; y: welcome.still ? 0 : 18 }
                anchors.horizontalCenter: parent.horizontalCenter
                y: logo.y + logo.height + 34
                text: qsTr("Welcome to f1int")
                color: Theme.fg
                font.pixelSize: Theme.px(38)
                font.weight: Font.DemiBold
                font.letterSpacing: -0.5
                opacity: welcome.still ? 1 : 0
            }
            Text {
                id: tagline
                transform: Translate { id: taglineRise; y: welcome.still ? 0 : 18 }
                anchors.horizontalCenter: parent.horizontalCenter
                y: hello.y + hello.height + 10
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("A light, quick browser that keeps your things on your computer.")
                color: Theme.dim
                font.pixelSize: Theme.px(16)
                opacity: welcome.still ? 1 : 0
            }
            Row {
                id: promises
                transform: Translate { id: promisesRise; y: welcome.still ? 0 : 18 }
                anchors.horizontalCenter: parent.horizontalCenter
                y: tagline.y + tagline.height + 30
                spacing: 10
                opacity: welcome.still ? 1 : 0
                Repeater {
                    model: [{ icon: "memory", text: qsTr("Uses less memory") },
                            { icon: "shield", text: qsTr("Blocks ads and trackers") },
                            { icon: "key", text: qsTr("Passwords stay encrypted here") }]
                    Rectangle {
                        required property var modelData
                        width: chip.implicitWidth + 28
                        height: 34
                        radius: 17
                        color: Theme.field
                        Row {
                            id: chip
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { glyph: parent.parent.modelData.icon; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: parent.parent.modelData.text; color: Theme.fg; font.pixelSize: Theme.px(13); anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            // The opening: logo pops in, strikes (a small swing and a burst of sparks), words rise.
            SequentialAnimation {
                id: intro
                running: !welcome.still
                PauseAnimation { duration: 250 }
                ParallelAnimation {
                    NumberAnimation { target: logo; property: "scale"; to: 1; duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    NumberAnimation { target: logo; property: "opacity"; to: 1; duration: 400 }
                }
                SequentialAnimation {
                    NumberAnimation { target: logo; property: "rotation"; to: -10; duration: 160; easing.type: Easing.OutQuad }
                    NumberAnimation { target: logo; property: "rotation"; to: 4; duration: 90; easing.type: Easing.InQuad }
                    ScriptAction { script: welcome.spark(60) }
                    NumberAnimation { target: logo; property: "rotation"; to: 0; duration: 380; easing.type: Easing.OutElastic }
                }
                ParallelAnimation {
                    NumberAnimation { target: hello; property: "opacity"; to: 1; duration: 500 }
                    NumberAnimation { target: helloRise; property: "y"; to: 0; duration: 600; easing.type: Easing.OutCubic }
                    SequentialAnimation {
                        PauseAnimation { duration: 140 }
                        ParallelAnimation {
                            NumberAnimation { target: tagline; property: "opacity"; to: 1; duration: 500 }
                            NumberAnimation { target: taglineRise; property: "y"; to: 0; duration: 600; easing.type: Easing.OutCubic }
                        }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 300 }
                        ParallelAnimation {
                            NumberAnimation { target: promises; property: "opacity"; to: 1; duration: 500 }
                            NumberAnimation { target: promisesRise; property: "y"; to: 0; duration: 600; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
            // Every few seconds the logo strikes again, while this page is open.
            Timer {
                interval: 3600
                repeat: true
                running: !welcome.still && welcome.step === 0 && !intro.running
                onTriggered: strike.start()
            }
            SequentialAnimation {
                id: strike
                NumberAnimation { target: logo; property: "rotation"; to: -8; duration: 150; easing.type: Easing.OutQuad }
                NumberAnimation { target: logo; property: "rotation"; to: 3; duration: 80; easing.type: Easing.InQuad }
                ScriptAction { script: welcome.spark(30) }
                NumberAnimation { target: logo; property: "rotation"; to: 0; duration: 340; easing.type: Easing.OutElastic }
            }
            MouseArea {   // click the logo for more sparks
                anchors.fill: logo
                cursorShape: Qt.PointingHandCursor
                onClicked: strike.start()
            }
        }

        // 2. Bring your stuff over.
        Page {
            id: movePage
            index: 1
            property var profiles: Browser.library.otherBrowserProfiles()
            property var picked: ({})          // path -> true
            property string state: ""          // "" | "busy" | "done"
            property int queue: 0
            property int bookmarks: 0
            property int visits: 0
            property string problem: ""
            Behavior on bookmarks { NumberAnimation { duration: welcome.still ? 0 : 900; easing.type: Easing.OutCubic } }
            Behavior on visits { NumberAnimation { duration: welcome.still ? 0 : 1400; easing.type: Easing.OutCubic } }
            Component.onCompleted: {
                // Tick the first profile of the first browser found; you can change it.
                const p = {}
                if (profiles.length > 0) p[profiles[0].path] = true
                picked = p
            }
            function pickedPaths() { return profiles.filter(p => picked[p.path]).map(p => p.path) }
            function start() {
                state = "busy"; problem = ""; bookmarks = 0; visits = 0; queue = 0
                importTimer.start()
            }
            // One profile per tick, so the loader keeps moving between them.
            Timer {
                id: importTimer
                interval: 60
                onTriggered: {
                    const paths = movePage.pickedPaths()
                    if (movePage.queue >= paths.length) { movePage.state = "done"; return }
                    const r = Browser.library.importProfile(paths[movePage.queue++])
                    movePage.bookmarks += r.bookmarks || 0
                    movePage.visits += r.history || 0
                    if (r.error) movePage.problem = r.error
                    restart()
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 14
                Text { text: qsTr("Bring your stuff over"); color: Theme.fg; font.pixelSize: Theme.px(30); font.weight: Font.DemiBold }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("Copy bookmarks and history from the browser you use now. Nothing changes in that browser.")
                    color: Theme.dim
                    font.pixelSize: Theme.px(14)
                }

                Text {
                    visible: movePage.profiles.length === 0
                    Layout.topMargin: 10
                    text: qsTr("No other browsers found on this computer. You can import later from Settings.")
                    color: Theme.dim
                    font.pixelSize: Theme.px(14)
                }
                // One row per profile found (Chrome, Edge, Brave …), each with a switch.
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 200)
                    visible: movePage.profiles.length > 0
                    clip: true
                    Column {
                        width: movePage.width
                        spacing: 6
                        Repeater {
                            model: movePage.profiles
                            Rectangle {
                                id: profileRow
                                required property var modelData
                                required property int index
                                readonly property bool on: !!movePage.picked[modelData.path]
                                width: parent.width
                                height: 52
                                radius: Theme.radius
                                color: on ? Theme.accentSoft : Theme.field
                                Behavior on color { ColorAnimation { duration: Theme.anim } }
                                opacity: movePage.current ? 1 : 0
                                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: welcome.still ? 0 : 120 + profileRow.index * 70 } NumberAnimation { duration: welcome.slow } } }
                                Rectangle {   // a letter, not the browser's logo
                                    id: letter
                                    x: 12; anchors.verticalCenter: parent.verticalCenter
                                    width: 30; height: 30; radius: 15
                                    color: Theme.surface
                                    Text { anchors.centerIn: parent; text: profileRow.modelData.browser.charAt(0); color: Theme.fg; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold }
                                }
                                Column {
                                    anchors { left: letter.right; leftMargin: 12; verticalCenter: parent.verticalCenter; right: toggle.left; rightMargin: 12 }
                                    Text { text: profileRow.modelData.browser; color: Theme.fg; font.pixelSize: Theme.px(14); font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width }
                                    Text { text: profileRow.modelData.name; color: Theme.dim; font.pixelSize: Theme.px(12); elide: Text.ElideRight; width: parent.width }
                                }
                                Ui.Toggle {
                                    id: toggle
                                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                    checked: profileRow.on
                                    enabled: movePage.state !== "busy"
                                    Accessible.name: profileRow.modelData.browser + " " + profileRow.modelData.name
                                    onToggled: { const p = Object.assign({}, movePage.picked); p[profileRow.modelData.path] = checked; movePage.picked = p }
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    visible: movePage.profiles.length > 0
                    spacing: 14
                    Ui.Pill {
                        primary: true
                        text: movePage.state === "done" ? qsTr("Import again") : qsTr("Import")
                        enabled: movePage.state !== "busy" && movePage.pickedPaths().length > 0
                        onClicked: movePage.start()
                    }
                    DotLoader { visible: movePage.state === "busy" }
                    Text {
                        visible: movePage.state !== ""
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr("%1 bookmarks and %2 visits added").arg(movePage.bookmarks.toLocaleString(Qt.locale(), "f", 0))
                                                                     .arg(movePage.visits.toLocaleString(Qt.locale(), "f", 0))
                              + (movePage.problem ? ". " + movePage.problem : "")
                        color: Theme.fg
                        font.pixelSize: Theme.px(14)
                        font.family: Theme.numberFont
                    }
                }

                // Passwords: browsers lock them, so you export a file first.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    implicitHeight: pw.implicitHeight + 32
                    radius: Theme.cardRadius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.line
                    ColumnLayout {
                        id: pw
                        anchors { fill: parent; margins: 16 }
                        spacing: 10
                        readonly property string vaultState: Browser.passwords.state
                        property string result: ""
                        RowLayout {
                            spacing: 8
                            Icon { glyph: "key"; color: Theme.accent }
                            Text { text: qsTr("Passwords"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold }
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: Theme.dim
                            font.pixelSize: Theme.px(13)
                            text: qsTr("Browsers keep saved passwords locked, so export them first. In Chrome: Settings › Autofill and passwords › Google Password Manager › Settings › Export passwords. Then choose that file here.")
                        }
                        RowLayout {
                            spacing: 10
                            Ui.Field {
                                id: master
                                visible: pw.vaultState !== "unlocked"
                                Layout.preferredWidth: 260
                                echoMode: TextInput.Password
                                placeholderText: pw.vaultState === "none" ? qsTr("New master password (8+ characters)") : qsTr("Your f1int master password")
                            }
                            Ui.Pill {
                                text: qsTr("Choose file…")
                                enabled: pw.vaultState === "unlocked" || master.text.length >= 8
                                onClicked: csvDialog.open()
                            }
                        }
                        Text {
                            visible: pw.result !== ""
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: pw.result
                            color: Theme.fg
                            font.pixelSize: Theme.px(13)
                        }
                        FileDialog {
                            id: csvDialog
                            title: qsTr("Choose the exported passwords file")
                            nameFilters: [qsTr("Password files (*.csv)")]
                            onAccepted: {
                                const v = Browser.passwords
                                if (v.state === "none" && !v.setUp(master.text, true)) { pw.result = qsTr("Couldn't create the password vault."); return }
                                if (v.state === "locked" && !v.unlock(master.text)) { pw.result = qsTr("That master password isn't right."); return }
                                master.text = ""
                                const n = v.importCsv(selectedFile)
                                pw.result = n < 0 ? qsTr("That file couldn't be read. Is it the exported CSV?")
                                                  : qsTr("Imported %1 passwords. Now delete the exported file: it isn't encrypted.").arg(n)
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // 3. Make it yours: the main look choices, with a live preview.
        Page {
            index: 2
            function set(k, v) { Browser.setSetting(k, v) }
            ColumnLayout {
                anchors.fill: parent
                spacing: 14
                Text { text: qsTr("Make it yours"); color: Theme.fg; font.pixelSize: Theme.px(30); font.weight: Font.DemiBold }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("Pick a theme. You can change every colour, corner and spacing later in Settings > Appearance.")
                    color: Theme.dim
                    font.pixelSize: Theme.px(14)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 28
                    ColumnLayout {
                        spacing: 14
                        Ui.Segmented {
                            options: [{ label: qsTr("Dark"), value: "dark" }, { label: qsTr("Light"), value: "light" }, { label: qsTr("System"), value: "system" }]
                            value: Theme.mode
                            onPicked: (v) => Browser.setSetting("appearance/theme", v)
                        }
                        GridLayout {   // the six presets
                            columns: 3
                            columnSpacing: 8
                            rowSpacing: 8
                            Repeater {
                                model: Theme.presetOrder
                                Rectangle {
                                    id: presetCard
                                    required property string modelData
                                    readonly property var p: Theme.presets[modelData]
                                    readonly property bool on: Theme.preset === modelData
                                    Layout.preferredWidth: 112
                                    Layout.preferredHeight: 52
                                    radius: Theme.radius
                                    color: p.frame
                                    border.width: on ? 2 : 1
                                    border.color: on ? Theme.accent : Theme.line
                                    Accessible.role: Accessible.RadioButton
                                    Accessible.name: p.name
                                    Accessible.checked: on
                                    Rectangle { x: 4; y: 4; width: 20; height: parent.height - 8; radius: 4; color: presetCard.p.sidebar }
                                    Rectangle { x: 30; y: 10; width: 10; height: 10; radius: 5; color: presetCard.p.accent }
                                    Rectangle { x: 44; y: 10; width: 10; height: 10; radius: 5; color: presetCard.p.accent2 }
                                    Text { x: 30; y: 28; text: presetCard.p.name; color: presetCard.p.fg; font.pixelSize: Theme.px(12) }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            Browser.setSetting(presetCard.p.light ? "appearance/lightPreset" : "appearance/darkPreset", presetCard.modelData)
                                            if (Theme.mode !== "system") Browser.setSetting("appearance/theme", presetCard.p.light ? "light" : "dark")
                                        }
                                    }
                                }
                            }
                        }
                        Ui.Segmented {
                            options: [{ label: qsTr("Tabs on the left"), value: "left" }, { label: qsTr("Tabs on the right"), value: "right" }]
                            value: Theme.tabsOnRight ? "right" : "left"
                            onPicked: (v) => Browser.setSetting("layout/tabsSide", v)
                        }
                    }
                    // A tiny f1int window that follows the choices above.
                    Rectangle {
                        id: preview
                        Layout.preferredWidth: 230
                        Layout.preferredHeight: 156
                        Layout.alignment: Qt.AlignTop
                        radius: 12
                        color: Theme.chromeSolid
                        border.width: 1
                        border.color: Theme.line
                        Behavior on color { ColorAnimation { duration: Theme.anim * 2 } }
                        Rectangle {   // address bar
                            x: 10; y: 9; width: parent.width - 20; height: 14; radius: 7
                            color: Theme.field
                            Rectangle { x: 5; anchors.verticalCenter: parent.verticalCenter; width: 5; height: 5; radius: 2.5; color: Theme.accent }
                        }
                        Column {   // tabs
                            x: Theme.tabsOnRight ? parent.width - 62 : 10
                            y: 32
                            spacing: 5
                            Behavior on x { NumberAnimation { duration: Theme.anim * 2; easing.type: Easing.OutCubic } }
                            Repeater {
                                model: 5
                                Rectangle {
                                    required property int index
                                    width: 52; height: 12; radius: 4
                                    color: index === 1 ? Theme.selected : "transparent"
                                    Rectangle { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 30 - parent.index * 3; height: 3; radius: 1.5; color: Theme.dim; opacity: 0.7 }
                                }
                            }
                        }
                        Rectangle {   // page
                            x: Theme.tabsOnRight ? 8 : 70
                            y: 32
                            width: parent.width - 78; height: parent.height - 40
                            radius: 8
                            color: Theme.bg
                            Behavior on x { NumberAnimation { duration: Theme.anim * 2; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Theme.anim * 2 } }
                            Rectangle { x: 12; y: 14; width: 60; height: 5; radius: 2.5; color: Theme.fg; opacity: 0.5 }
                            Rectangle { x: 12; y: 26; width: parent.width - 24; height: 3; radius: 1.5; color: Theme.dim; opacity: 0.4 }
                            Rectangle { x: 12; y: 34; width: parent.width - 40; height: 3; radius: 1.5; color: Theme.dim; opacity: 0.4 }
                            Rectangle { x: 12; y: 50; width: 34; height: 12; radius: 6; color: Theme.accent }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // 4. Search and privacy.
        Page {
            index: 3
            ColumnLayout {
                anchors.fill: parent
                spacing: 14
                Text { text: qsTr("Search and privacy"); color: Theme.fg; font.pixelSize: Theme.px(30); font.weight: Font.DemiBold }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("What you type in the address bar goes to this search engine. f1int itself sends nothing anywhere.")
                    color: Theme.dim
                    font.pixelSize: Theme.px(14)
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 8
                    Repeater {
                        model: Browser.searchEngines
                        Rectangle {
                            required property var modelData
                            readonly property bool on: Theme.setting("search/template", "https://www.google.com/search?q=%s") === modelData.template
                            width: engineName.implicitWidth + 32
                            height: 38
                            radius: 19
                            color: on ? Theme.accentSoft : Theme.field
                            border.width: on ? 1 : 0
                            border.color: Theme.accent
                            Accessible.role: Accessible.RadioButton
                            Accessible.name: modelData.name
                            Accessible.checked: on
                            Text { id: engineName; anchors.centerIn: parent; text: parent.modelData.name; color: Theme.fg; font.pixelSize: Theme.px(14) }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: Browser.setSetting("search/template", parent.modelData.template) }
                        }
                    }
                }
                GridLayout {
                    Layout.topMargin: 14
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 16
                    Column {
                        Text { text: qsTr("Block ads and trackers"); color: Theme.fg; font.pixelSize: Theme.px(14) }
                        Text { text: qsTr("Pages load faster and follow you less"); color: Theme.dim; font.pixelSize: Theme.px(12) }
                    }
                    Ui.Toggle { checked: Browser.setting("privacy/adblock", true); onToggled: Browser.setSetting("privacy/adblock", checked) }
                    Column {
                        Text { text: qsTr("Memory saver"); color: Theme.fg; font.pixelSize: Theme.px(14) }
                        Text { text: qsTr("Puts tabs you aren't using to sleep"); color: Theme.dim; font.pixelSize: Theme.px(12) }
                    }
                    Ui.Segmented {
                        options: [{ label: qsTr("Off"), value: "off" }, { label: qsTr("Balanced"), value: "balanced" }, { label: qsTr("Max"), value: "max" }]
                        value: Theme.setting("memory/saver", "balanced")
                        onPicked: (v) => Browser.setSetting("memory/saver", v)
                    }
                    Column {
                        Text { text: qsTr("New tabs open"); color: Theme.fg; font.pixelSize: Theme.px(14) }
                        Text { text: qsTr("f1int's page has your shortcuts, notes and a picture"); color: Theme.dim; font.pixelSize: Theme.px(12) }
                    }
                    Ui.Segmented {
                        options: [{ label: qsTr("Google"), value: "home" }, { label: qsTr("f1int page"), value: "f1int" }]
                        value: Theme.setting("newtab/mode", "home") === "f1int" ? "f1int" : "home"
                        onPicked: (v) => Browser.setSetting("newtab/mode", v)
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // 5. Done: a tick, a last burst of sparks and a few shortcuts worth knowing.
        Page {
            id: donePage
            index: 4
            onCurrentChanged: if (current) { tick.scale = welcome.still ? 1 : 0.3; tickIn.restart() }
            Component.onCompleted: tick.scale = 0.3
            Rectangle {
                id: tick
                anchors.horizontalCenter: parent.horizontalCenter
                y: 20
                width: 84; height: 84; radius: 42
                color: Theme.accent
                Icon { anchors.centerIn: parent; glyph: "check"; color: Theme.textOnAccent; sourceSize: Qt.size(36, 36) }
            }
            SequentialAnimation {
                id: tickIn
                NumberAnimation { target: tick; property: "scale"; to: 1; duration: welcome.still ? 0 : 520; easing.type: Easing.OutBack; easing.overshoot: 2 }
                ScriptAction { script: welcome.sparkAt(tick, 0.5, 0.5, 50) }
            }
            Text {
                id: doneTitle
                anchors.horizontalCenter: parent.horizontalCenter
                y: tick.y + tick.height + 26
                text: qsTr("You're all set")
                color: Theme.fg
                font.pixelSize: Theme.px(32)
                font.weight: Font.DemiBold
            }
            Text {
                id: doneHint
                anchors.horizontalCenter: parent.horizontalCenter
                y: doneTitle.y + doneTitle.height + 8
                text: qsTr("A few shortcuts worth knowing:")
                color: Theme.dim
                font.pixelSize: Theme.px(14)
            }
            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                y: doneHint.y + doneHint.height + 22
                columns: 2
                columnSpacing: 36
                rowSpacing: 12
                Repeater {
                    model: [{ keys: [welcome.mod, "T"], text: qsTr("New tab") },
                            { keys: [welcome.mod, "L"], text: qsTr("Go to the address bar") },
                            { keys: [welcome.mod, "Shift", "S"], text: qsTr("Hide the tab bar") },
                            { keys: [welcome.mod, "Shift", "T"], text: qsTr("Reopen a closed tab") },
                            { keys: [welcome.mod, "D"], text: qsTr("Bookmark this page") },
                            { keys: [welcome.mod, ","], text: qsTr("Settings") }]
                    Row {
                        required property var modelData
                        spacing: 10
                        Row {
                            width: 130
                            spacing: 4
                            Repeater {
                                model: parent.parent.modelData.keys
                                Rectangle {   // a key cap
                                    required property string modelData
                                    width: Math.max(26, capText.implicitWidth + 14)
                                    height: 26
                                    radius: 6
                                    color: Theme.field
                                    border.width: 1
                                    border.color: Theme.line
                                    Text { id: capText; anchors.centerIn: parent; text: parent.modelData; color: Theme.fg; font.pixelSize: Theme.px(12); font.weight: Font.Medium }
                                }
                            }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.text; color: Theme.fg; font.pixelSize: Theme.px(14) }
                    }
                }
            }
        }
    }

    // ---------- bottom: progress and buttons ----------
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        spacing: 6
        Repeater {
            model: welcome.steps
            Rectangle {
                required property int index
                width: index === welcome.step ? 26 : 8
                height: 8
                radius: 4
                color: index <= welcome.step ? Theme.accent : Theme.line
                Behavior on width { NumberAnimation { duration: welcome.slow; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: welcome.slow } }
                Accessible.ignored: true
            }
        }
    }
    Ui.Pill {
        anchors { left: parent.left; bottom: parent.bottom; margins: 28 }
        visible: welcome.step > 0
        text: qsTr("Back")
        onClicked: welcome.back()
    }
    Ui.Pill {
        id: nextButton
        anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
        primary: true
        text: [qsTr("Get started"), qsTr("Next"), qsTr("Next"), qsTr("Next"), qsTr("Start browsing")][welcome.step]
        onClicked: welcome.next()
    }
}
