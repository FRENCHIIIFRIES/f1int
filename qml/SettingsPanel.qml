import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import f1int

// Settings, laid out like a phone's settings screen: grouped sections with toggles.
// Every change is saved and applied straight away.
Rectangle {
    id: panel
    signal closeRequested()
    signal openPasswordsRequested()

    function get(key, fallback) { void Browser.settingsRevision; return Browser.setting(key, fallback) }
    function set(key, value) { Browser.setSetting(key, value) }

    color: Theme.surface
    Rectangle { width: 1; height: parent.height; color: Theme.line }

    // Colour wheel + hex code, for a custom accent or a custom window tint.
    Popup {
        id: colorPopup
        property string target: "accent"   // "accent" | "tint"
        function openFor(what) { target = what; open() }
        x: (panel.width - width) / 2
        y: 80
        width: 260
        padding: 18
        modal: true
        background: Rectangle { color: Theme.surface; radius: Theme.cardRadius; border.width: 1; border.color: Theme.line }
        contentItem: ColorWheel {
            color: colorPopup.target === "tint" ? Theme.customColor
                 : Theme.accent
            onPicked: (c) => {
                if (colorPopup.target === "tint") {
                    panel.set("appearance/customTint", c.toString())
                    panel.set("appearance/tint", "custom")
                } else {
                    panel.set("appearance/accent", c.toString())
                }
                colorPopup.close()
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { width: 4 }

        ColumnLayout {
            id: content
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 22

            RowLayout {
                Layout.fillWidth: true
                Ui.Heading { text: qsTr("Settings") }
                Item { Layout.fillWidth: true }
                IconButton { iconName: "close"; tip: qsTr("Close"); onClicked: panel.closeRequested() }
            }

            // ---------------- Appearance: everything about how f1int looks ----------------
            Ui.Section {
                title: qsTr("Look")
                Ui.SettingRow {
                    label: qsTr("Theme")
                    Ui.Segmented {
                        options: [{ label: qsTr("Dark"), value: "dark" }, { label: qsTr("Light"), value: "light" },
                                  { label: qsTr("System"), value: "system" }]
                        value: panel.get("appearance/theme", "dark")
                        onPicked: (v) => { panel.set("appearance/theme", v); panel.set("appearance/tint", "") }
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Tint")
                    hint: Theme.customTint ? qsTr("Your own colour (click it to change)")
                          : Theme.dark ? qsTr("Graphite is soft grey, Midnight is deeper, or pick your own")
                                       : qsTr("Paper is warm white, Mist is cool, or pick your own")
                    Row {
                        spacing: 8
                        Repeater {
                            model: Theme.dark ? ["graphite", "midnight"] : ["paper", "mist"]
                            Rectangle {
                                required property string modelData
                                readonly property bool on: Theme.tint === modelData
                                width: 64
                                height: 34
                                radius: Theme.radius
                                color: Theme.tints[modelData].chrome
                                border.width: on ? 2 : 1
                                border.color: on ? Theme.accent : Theme.line
                                Accessible.role: Accessible.RadioButton
                                Accessible.name: modelData
                                Accessible.checked: on
                                Rectangle {   // a little "page" on the tint, like the real window
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    anchors.leftMargin: 22
                                    radius: Math.max(2, Theme.radius - 4)
                                    color: Theme.tints[parent.modelData].panel
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: panel.set("appearance/tint", parent.modelData) }
                            }
                        }
                        Rectangle {   // Custom: any colour from the colour wheel
                            readonly property bool on: Theme.customTint
                            width: 64
                            height: 34
                            radius: Theme.radius
                            color: Theme.customColor
                            border.width: on ? 2 : 1
                            border.color: on ? Theme.accent : Theme.line
                            Accessible.role: Accessible.RadioButton
                            Accessible.name: qsTr("Custom tint")
                            Accessible.checked: on
                            Icon {
                                anchors.centerIn: parent
                                glyph: "plus"
                                color: Theme.brightness(Theme.customColor) > 0.5 ? "#1d1d20" : "#e9e9ec"
                            }
                            HoverHandler { id: customHover; cursorShape: Qt.PointingHandCursor }
                            ToolTip.visible: customHover.hovered
                            ToolTip.text: qsTr("Pick your own colour")
                            MouseArea { anchors.fill: parent; onClicked: colorPopup.openFor("tint") }
                        }
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Accent colour")
                    hint: Theme.accentSetting === "auto" ? qsTr("Automatic: picked to suit your tint") : qsTr("Used for focus, switches and main buttons")
                    Row {
                        spacing: 6
                        Repeater {
                            model: ["auto", "#4c8df6", "#3fa877", "#9d6fd6", "#e0569b", "#D71921", "#8a8a8a", "fg"]
                            Rectangle {
                                required property string modelData
                                readonly property color shown: modelData === "auto" ? Theme.autoAccent : modelData === "fg" ? Theme.fg : modelData
                                readonly property bool on: Theme.accentSetting.toLowerCase() === modelData.toLowerCase()
                                width: 24
                                height: 24
                                radius: 12
                                color: "transparent"
                                border.width: on ? 2 : 0
                                border.color: Theme.fg
                                Accessible.role: Accessible.RadioButton
                                Accessible.name: modelData === "auto" ? qsTr("Automatic") : modelData === "fg" ? qsTr("Plain") : modelData
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: parent.shown
                                    Text {   // "A" marks the automatic colour
                                        anchors.centerIn: parent
                                        visible: parent.parent.modelData === "auto"
                                        text: "A"
                                        color: Theme.textOnAccent
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                    }
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: panel.set("appearance/accent", parent.modelData) }
                            }
                        }
                        IconButton { iconName: "plus"; iconColor: Theme.dim; tip: qsTr("Any colour (wheel or hex code)"); onClicked: colorPopup.openFor("accent") }
                    }
                }
                Ui.SettingRow {
                    visible: Qt.platform.os === "windows"
                    label: qsTr("Frosted glass")
                    hint: qsTr("Your wallpaper shows softly through the window")
                    Ui.Toggle { checked: panel.get("appearance/glass", true); onToggled: panel.set("appearance/glass", checked) }
                }
                Ui.SettingRow {
                    visible: Theme.glass
                    label: qsTr("Glass tint")
                    hint: qsTr("Less tint shows more of the desktop")
                    last: true
                    Ui.Slide { width: 160; from: 0; to: 0.95; value: Theme.glassTint; onMoved: panel.set("appearance/glassTint", Math.round(value * 100) / 100) }
                }
            }

            Ui.Section {
                title: qsTr("Shape and text")
                Ui.SettingRow {
                    label: qsTr("Corners")
                    Row {
                        spacing: 10
                        Ui.Slide { width: 140; from: 0; to: 16; stepSize: 1; value: Theme.radius; onMoved: panel.set("appearance/roundness", value) }
                        Text { text: Theme.radius === 0 ? qsTr("Square") : Theme.radius + " px"; color: Theme.dim; font.pixelSize: Theme.px(12); width: 48; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Spacing")
                    Ui.Segmented {
                        options: [{ label: qsTr("Compact"), value: "compact" }, { label: qsTr("Comfortable"), value: "comfortable" },
                                  { label: qsTr("Spacious"), value: "spacious" }]
                        value: Theme.density
                        onPicked: (v) => panel.set("appearance/density", v)
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Text size")
                    Ui.Segmented {
                        options: [{ label: "90%", value: 0.9 }, { label: "100%", value: 1.0 }, { label: "110%", value: 1.1 }, { label: "125%", value: 1.25 }]
                        value: Theme.textScale
                        onPicked: (v) => panel.set("appearance/textScale", v)
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
                        currentIndex: Math.max(0, model.indexOf(panel.get("appearance/font", qsTr("System"))))
                        onActivated: (i) => panel.set("appearance/font", i === 0 ? "" : model[i])
                        background: Rectangle { radius: Theme.radius; color: Theme.field }
                        contentItem: Text { leftPadding: 12; text: fontBox.displayText; color: Theme.fg; font.pixelSize: Theme.px(13); verticalAlignment: Text.AlignVCenter }
                        indicator: Icon { glyph: "down"; color: Theme.dim; sourceSize: Qt.size(14, 14); x: fontBox.width - width - 10; y: (fontBox.height - height) / 2 }
                        popup.background: Rectangle { radius: Theme.cardRadius; color: Theme.surface; border.width: 1; border.color: Theme.line }
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Dot-matrix numbers")
                    hint: qsTr("Tab count, memory and clock in a dotted display font")
                    last: true
                    Ui.Toggle { checked: panel.get("appearance/dotNumbers", false); onToggled: panel.set("appearance/dotNumbers", checked) }
                }
            }

            Ui.Section {
                title: qsTr("Layout")
                Ui.SettingRow {
                    label: qsTr("Tab bar")
                    Ui.Segmented {
                        options: [{ label: qsTr("Left"), value: "left" }, { label: qsTr("Right"), value: "right" }]
                        value: panel.get("layout/tabsSide", "left")
                        onPicked: (v) => panel.set("layout/tabsSide", v)
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Address bar")
                    Ui.Segmented {
                        options: [{ label: qsTr("Top of window"), value: "window" }, { label: qsTr("Above page"), value: "page" }, { label: qsTr("In tab bar"), value: "sidebar" }]
                        value: panel.get("layout/address", "window")
                        onPicked: (v) => panel.set("layout/address", v)
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Space around the page")
                    Ui.Segmented {
                        options: [{ label: qsTr("None"), value: 0 }, { label: qsTr("Small"), value: 8 }, { label: qsTr("Large"), value: 16 }]
                        value: Theme.inset
                        onPicked: (v) => panel.set("appearance/inset", v)
                    }
                }
                Ui.SettingRow { label: qsTr("Home button"); Ui.Toggle { checked: Theme.showHome; onToggled: panel.set("layout/showHome", checked) } }
                Ui.SettingRow { label: qsTr("Downloads button"); hint: qsTr("Always shown while something downloads"); Ui.Toggle { checked: Theme.showDownloads; onToggled: panel.set("layout/showDownloads", checked) } }
                Ui.SettingRow { label: qsTr("Number of tabs"); Ui.Toggle { checked: Theme.showTabCount; onToggled: panel.set("layout/showTabCount", checked) } }
                Ui.SettingRow { label: qsTr("Memory use in the tab bar"); last: true; Ui.Toggle { checked: Theme.showRam; onToggled: panel.set("layout/showRam", checked) } }
            }

            Ui.Section {
                title: qsTr("Motion")
                Ui.SettingRow {
                    label: qsTr("Animations")
                    hint: Browser.reduceMotion ? qsTr("Off, because Windows' animation effects are off") : ""
                    last: true
                    Ui.Segmented {
                        options: [{ label: qsTr("Off"), value: "off" }, { label: qsTr("Fast"), value: "fast" }, { label: qsTr("Normal"), value: "normal" }]
                        value: Theme.motion
                        onPicked: (v) => panel.set("appearance/motion", v)
                    }
                }
            }
            Ui.Pill {
                text: qsTr("Reset appearance")
                onClicked: {
                    for (const key of ["appearance/theme", "appearance/tint", "appearance/customTint", "appearance/accent", "appearance/glass", "appearance/glassTint",
                                       "appearance/roundness", "appearance/density", "appearance/textScale", "appearance/font",
                                       "appearance/dotNumbers", "appearance/inset", "appearance/motion", "layout/tabsSide", "layout/address",
                                       "layout/showHome", "layout/showDownloads", "layout/showTabCount", "layout/showRam"])
                        Browser.resetSetting(key)
                }
            }

            Ui.Section {
                title: qsTr("Search and home")
                Ui.SettingRow {
                    label: qsTr("Search engine")
                    hint: qsTr("Used when you type words in the address bar")
                    ComboBox {
                        id: engine
                        width: 170
                        model: Browser.searchEngines.map(e => e.name)
                        currentIndex: Math.max(0, Browser.searchEngines.findIndex(e => e.template === panel.get("search/template", "https://www.google.com/search?q=%s")))
                        onActivated: (i) => panel.set("search/template", Browser.searchEngines[i].template)
                        implicitHeight: 32
                        // Same look as our text fields: thin border, rounded, chevron on the right.
                        background: Rectangle { radius: 8; color: Theme.bg; border.width: 1; border.color: engine.activeFocus ? Theme.dim : Theme.line }
                        contentItem: Text {
                            leftPadding: 12
                            text: engine.displayText
                            color: Theme.fg
                            font.pixelSize: Theme.px(13)
                            verticalAlignment: Text.AlignVCenter
                        }
                        indicator: Icon { glyph: "down"; color: Theme.dim; sourceSize: Qt.size(14, 14); x: engine.width - width - 10; y: (engine.height - height) / 2 }
                        delegate: ItemDelegate {
                            required property int index
                            required property string modelData
                            width: engine.width
                            height: 32
                            contentItem: Text { text: parent.modelData; color: Theme.fg; font.pixelSize: Theme.px(13); verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { radius: 6; color: parent.highlighted || parent.hovered ? Theme.hover : "transparent" }
                            highlighted: engine.highlightedIndex === index
                        }
                        popup.background: Rectangle { radius: 10; color: Theme.surface; border.width: 1; border.color: Theme.line }
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Home page")
                    Ui.Field {
                        width: 200
                        text: panel.get("home/url", "https://www.google.com")
                        onEditingFinished: {
                            const url = Browser.urlFromInput(text)
                            if (url.toString() !== "") panel.set("home/url", url)
                        }
                    }
                }
                Ui.SettingRow {
                    label: qsTr("New tabs open")
                    hint: qsTr("Customise f1int's page with the dot button in its corner")
                    last: panel.get("newtab/mode", "home") !== "custom"
                    Ui.Segmented {
                        options: [{ label: "f1int", value: "f1int" }, { label: qsTr("Blank"), value: "blank" },
                                  { label: qsTr("Home"), value: "home" }, { label: qsTr("Address"), value: "custom" }]
                        value: panel.get("newtab/mode", "home")
                        onPicked: (v) => panel.set("newtab/mode", v)
                    }
                }
                Ui.SettingRow {
                    visible: panel.get("newtab/mode", "home") === "custom"
                    label: qsTr("New tab address")
                    last: true
                    Ui.Field {
                        width: 200
                        text: panel.get("newtab/url", "")
                        placeholderText: "example.com"
                        onEditingFinished: panel.set("newtab/url", text.trim())
                    }
                }
            }

            Ui.Section {
                title: qsTr("Tabs and memory")
                Ui.SettingRow {
                    label: qsTr("Reopen tabs on start")
                    hint: qsTr("Also after a crash. Only the open tab loads; the rest wait asleep.")
                    Ui.Toggle { checked: panel.get("startup/restore", true); onToggled: panel.set("startup/restore", checked) }
                }
                Ui.SettingRow {
                    label: qsTr("Memory saver")
                    hint: qsTr("Puts tabs you haven't used for a while to sleep. Tabs playing sound or with unsent forms stay awake.")
                    Ui.Segmented {
                        options: [{ label: qsTr("Off"), value: "off" }, { label: qsTr("Balanced"), value: "balanced" },
                                  { label: qsTr("Max"), value: "max" }]
                        value: panel.get("memory/saver", "balanced")
                        onPicked: (v) => panel.set("memory/saver", v)
                    }
                }
                Ui.SettingRow {
                    visible: panel.get("memory/saver", "balanced") === "balanced"
                    label: qsTr("Freeze after")
                    hint: qsTr("A frozen tab keeps its page but stops running")
                    Ui.Segmented {
                        options: [1, 2, 5, 10].map(m => ({ label: m + " min", value: m }))
                        value: Number(panel.get("memory/freezeMinutes", 2))
                        onPicked: (v) => panel.set("memory/freezeMinutes", v)
                    }
                }
                Ui.SettingRow {
                    visible: panel.get("memory/saver", "balanced") === "balanced"
                    label: qsTr("Sleep after")
                    hint: qsTr("A sleeping tab frees its memory and reloads when you click it")
                    last: true
                    Ui.Segmented {
                        options: [5, 10, 30, 60].map(m => ({ label: m + " min", value: m }))
                        value: Number(panel.get("memory/discardMinutes", 10))
                        onPicked: (v) => panel.set("memory/discardMinutes", v)
                    }
                }
            }

            Ui.Section {
                title: qsTr("Passwords")
                Ui.SettingRow {
                    label: qsTr("Offer to save passwords")
                    Ui.Toggle { checked: panel.get("passwords/offer", true); onToggled: panel.set("passwords/offer", checked) }
                }
                Ui.SettingRow {
                    label: qsTr("Fill in saved passwords")
                    Ui.Toggle { checked: panel.get("passwords/autofill", true); onToggled: panel.set("passwords/autofill", checked) }
                }
                Ui.SettingRow {
                    label: qsTr("Suggest strong passwords on sign-up forms")
                    Ui.Toggle { checked: panel.get("passwords/generator", true); onToggled: panel.set("passwords/generator", checked) }
                }
                Ui.SettingRow {
                    label: qsTr("Lock passwords after")
                    hint: qsTr("Minutes without using them")
                    Ui.Segmented {
                        options: [{ label: "5", value: 5 }, { label: "15", value: 15 }, { label: "60", value: 60 }, { label: qsTr("Never"), value: 0 }]
                        value: Number(panel.get("passwords/autoLockMinutes", 15))
                        onPicked: (v) => panel.set("passwords/autoLockMinutes", v)
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Saved passwords")
                    hint: qsTr("Encrypted on this computer, never sent anywhere")
                    last: true
                    Ui.Pill { text: qsTr("Open"); onClicked: panel.openPasswordsRequested() }
                }
            }

            Ui.Section {
                title: qsTr("Import from another browser")
                Repeater {
                    model: Browser.library.otherBrowserProfiles()
                    Ui.SettingRow {
                        required property var modelData
                        property string result: ""
                        label: modelData.browser + " – " + modelData.name
                        hint: result !== "" ? result : qsTr("Bookmarks and history")
                        Ui.Pill {
                            text: qsTr("Import")
                            onClicked: {
                                const r = Browser.library.importProfile(parent.parent.modelData.path)
                                parent.parent.result = qsTr("Added %1 bookmarks and %2 history entries.").arg(r.bookmarks).arg(r.history)
                                                       + (r.error ? " " + r.error : "")
                            }
                        }
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Passwords")
                    hint: qsTr("Browsers lock their saved passwords, so export them first: in Chrome, open Settings › Passwords › Export, then use Import CSV in f1int's Passwords.")
                    last: true
                    Ui.Pill { text: qsTr("Passwords"); onClicked: panel.openPasswordsRequested() }
                }
            }

            Ui.Section {
                title: qsTr("Privacy")
                Ui.SettingRow {
                    label: qsTr("Block ads and trackers")
                    hint: qsTr("%1 requests blocked since start. Lists update weekly from easylist.to.").arg(Browser.blockedTotal)
                    Ui.Toggle { checked: panel.get("privacy/adblock", true); onToggled: panel.set("privacy/adblock", checked) }
                }
                Ui.SettingRow {
                    label: qsTr("Clear browsing data on exit")
                    hint: qsTr("History, cookies, cache and open tabs. Bookmarks are kept.")
                    Ui.Toggle { checked: panel.get("privacy/clearOnExit", false); onToggled: panel.set("privacy/clearOnExit", checked) }
                }
                Ui.SettingRow {
                    label: qsTr("Clear browsing data now")
                    hint: qsTr("Signs you out of websites")
                    last: true
                    Ui.Pill { id: clearNow; text: qsTr("Clear"); onClicked: { Browser.clearBrowsingData(); text = qsTr("Cleared") } }
                }
            }

            Ui.Section {
                title: qsTr("About")
                Ui.SettingRow {
                    label: "f1int " + Browser.version
                    hint: qsTr("Free and open source (MIT). Built on Qt (LGPL) and Chromium. No telemetry.")
                    last: true
                    Image { source: "qrc:/logo/f1int.svg"; sourceSize: Qt.size(40, 40) }
                }
            }
        }
    }
}
