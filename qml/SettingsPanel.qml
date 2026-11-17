import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import f1int

// Settings, laid out like a phone's settings screen: grouped sections with toggles.
// Every change is saved and applied straight away.
Rectangle {
    id: panel
    signal closeRequested()

    function get(key, fallback) { void Browser.settingsRevision; return Browser.setting(key, fallback) }
    function set(key, value) { Browser.setSetting(key, value) }

    color: Theme.surface
    Rectangle { width: 1; height: parent.height; color: Theme.line }

    // Colour wheel + hex code for a custom accent colour.
    Popup {
        id: colorPopup
        x: (panel.width - width) / 2
        y: 80
        width: 260
        padding: 18
        modal: true
        background: Rectangle { color: Theme.surface; radius: 16; border.width: 1; border.color: Theme.line }
        contentItem: ColorWheel {
            color: String(panel.get("appearance/accent", "#D71921")) === "fg" ? "#ffffff" : panel.get("appearance/accent", "#D71921")
            onPicked: (c) => { panel.set("appearance/accent", c.toString()); colorPopup.close() }
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
                Text { text: qsTr("SETTINGS"); color: Theme.fg; font.family: Theme.dotFont; font.pixelSize: 26; font.weight: Font.Black }
                Item { Layout.fillWidth: true }
                IconButton { iconName: "close"; tip: qsTr("Close"); onClicked: panel.closeRequested() }
            }

            Ui.Section {
                title: qsTr("Appearance")
                Ui.SettingRow {
                    label: qsTr("Theme")
                    Ui.Segmented {
                        options: [{ label: qsTr("Dark"), value: "dark" }, { label: qsTr("Light"), value: "light" },
                                  { label: qsTr("System"), value: "system" }]
                        value: panel.get("appearance/theme", "dark")
                        onPicked: (v) => panel.set("appearance/theme", v)
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Accent colour")
                    hint: qsTr("Used only for active and important things")
                    Row {
                        spacing: 8
                        Repeater {
                            model: ["#D71921", "fg", "#8a8a8a", "#d9a62e", "#3fa877", "#4c8df6"]
                            Rectangle {
                                required property string modelData
                                readonly property color shown: modelData === "fg" ? Theme.fg : modelData
                                width: 24
                                height: 24
                                radius: 12
                                color: "transparent"
                                border.width: panel.get("appearance/accent", "#D71921") === modelData ? 1.5 : 0
                                border.color: Theme.fg
                                Accessible.role: Accessible.RadioButton
                                Accessible.name: modelData === "fg" ? qsTr("White") : modelData
                                Rectangle { anchors.centerIn: parent; width: 16; height: 16; radius: 8; color: parent.shown; border.width: 1; border.color: Theme.line }
                                MouseArea { anchors.fill: parent; onClicked: panel.set("appearance/accent", parent.modelData) }
                            }
                        }
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Custom accent")
                    hint: qsTr("Any colour: colour wheel or hex code")
                    last: true
                    Ui.Pill { text: qsTr("Pick…"); onClicked: colorPopup.open() }
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
                        palette.button: Theme.bg
                        palette.buttonText: Theme.fg
                        palette.window: Theme.surface
                        palette.text: Theme.fg
                        palette.highlight: Theme.selected
                        palette.highlightedText: Theme.fg
                        palette.base: Theme.bg
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
                    last: panel.get("newtab/mode", "f1int") !== "custom"
                    Ui.Segmented {
                        options: [{ label: "f1int", value: "f1int" }, { label: qsTr("Blank"), value: "blank" },
                                  { label: qsTr("Home"), value: "home" }, { label: qsTr("Address"), value: "custom" }]
                        value: panel.get("newtab/mode", "f1int")
                        onPicked: (v) => panel.set("newtab/mode", v)
                    }
                }
                Ui.SettingRow {
                    visible: panel.get("newtab/mode", "f1int") === "custom"
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
