import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import f1int

// The Customise side panel: quick look changes beside the page you're on. The full set
// (every colour, saved themes, sharing) is in Settings > Appearance.
Rectangle {
    id: panel
    signal closeRequested()
    signal studioRequested()
    function set(key, value) { Browser.setSetting(key, value) }
    function setColour(role, value) { set("appearance/custom/" + Theme.preset + "/" + role, value) }

    color: Theme.surface
    Rectangle { width: 1; height: parent.height; color: Theme.line }

    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { width: 4 }
        ColumnLayout {
            id: content
            x: 18; y: 16
            width: parent.width - 36
            spacing: 18
            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Customise"); color: Theme.fg; font.pixelSize: Theme.px(20); font.weight: Font.DemiBold }
                Item { Layout.fillWidth: true }
                IconButton { iconName: "close"; tip: qsTr("Close"); onClicked: panel.closeRequested() }
            }
            Ui.Segmented {
                options: [{ label: qsTr("Dark"), value: "dark" }, { label: qsTr("Light"), value: "light" }, { label: qsTr("System"), value: "system" }]
                value: Theme.mode
                onPicked: (v) => panel.set("appearance/theme", v)
            }
            Text { text: qsTr("Theme"); color: Theme.dim; font.pixelSize: Theme.px(12) }
            GridLayout {
                columns: 3
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: Theme.presetOrder
                    Rectangle {
                        id: swatch
                        required property string modelData
                        readonly property var p: Theme.presets[modelData]
                        readonly property bool on: Theme.preset === modelData
                        Layout.preferredWidth: 104
                        Layout.preferredHeight: 64
                        radius: Theme.radius
                        color: p.frame
                        border.width: on ? 2 : 1
                        border.color: on ? Theme.accent : Theme.line
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: p.name
                        Accessible.checked: on
                        Rectangle { x: 4; y: 4; width: 22; height: parent.height - 8; radius: 4; color: swatch.p.sidebar }
                        Rectangle { x: 30; y: 4; width: parent.width - 34; height: parent.height - 26; radius: 4; color: swatch.p.panel
                            Rectangle { x: 6; y: 6; width: 14; height: 6; radius: 3; color: swatch.p.accent }
                            Rectangle { x: 23; y: 6; width: 6; height: 6; radius: 3; color: swatch.p.accent2 } }
                        Text { x: 32; y: parent.height - 18; text: swatch.p.name; color: swatch.p.fg; font.pixelSize: Theme.px(11) }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                panel.set(swatch.p.light ? "appearance/lightPreset" : "appearance/darkPreset", swatch.modelData)
                                if (Theme.mode !== "system") panel.set("appearance/theme", swatch.p.light ? "light" : "dark")
                            }
                        }
                    }
                }
            }
            // Your looks: saved themes (Work, Gaming, Night...), each a whole appearance. One click switches.
            Text { text: qsTr("Your looks"); color: Theme.dim; font.pixelSize: Theme.px(12) }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: Theme.savedThemes
                    Rectangle {
                        id: lookChip
                        required property var modelData
                        width: lookName.implicitWidth + 26
                        height: 30
                        radius: 15
                        color: lookHover.hovered ? Theme.hover : Theme.field
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Switch to %1").arg(modelData.name)
                        Text { id: lookName; anchors.centerIn: parent; text: lookChip.modelData.name; color: Theme.fg; font.pixelSize: Theme.px(12) }
                        HoverHandler { id: lookHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: Theme.apply(lookChip.modelData.values) }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Ui.Field { id: lookField; Layout.fillWidth: true; placeholderText: qsTr("Save this look as… (Work, Night)"); onAccepted: saveLook.clicked() }
                Ui.Pill {
                    id: saveLook
                    text: qsTr("Save")
                    enabled: lookField.text.trim() !== ""
                    onClicked: {
                        const name = lookField.text.trim().slice(0, 60)
                        const others = Theme.savedThemes.filter(t => t.name !== name)   // same name: replaced
                        Theme.storeThemes(others.concat([{ id: Date.now().toString(36), name: name, author: "", description: "", version: "1",
                                                           source: "mine", favourite: false, values: Theme.snapshot() }]))
                        lookField.text = ""
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Ui.Pill { text: qsTr("Undo"); enabled: Theme.canUndo; onClicked: Theme.history.undo() }
                Item { Layout.fillWidth: true }
            }
            // Accent pair: quick picks; any colour in the studio.
            Repeater {
                model: [{ role: "accent", label: qsTr("Accent"), colours: ["#9b7bff", "#6ea8ff", "#3fa877", "#e0569b", "#e5484d", "#f0f0f0"] },
                        { role: "accent2", label: qsTr("Second accent"), colours: ["#f2c94c", "#ffb547", "#5fd4c4", "#ff8fab", "#b7791f", "#d9d2d2"] }]
                ColumnLayout {
                    id: accentGroup
                    required property var modelData
                    spacing: 8
                    Text { text: accentGroup.modelData.label; color: Theme.dim; font.pixelSize: Theme.px(12) }
                    Row {
                        spacing: 6
                        Repeater {
                            model: accentGroup.modelData.colours
                            Rectangle {
                                required property string modelData
                                readonly property bool on: String(Theme[accentGroup.modelData.role]).toLowerCase() === modelData
                                width: 28; height: 28; radius: 14
                                color: "transparent"
                                border.width: on ? 2 : 0
                                border.color: Theme.fg
                                Accessible.role: Accessible.RadioButton
                                Accessible.name: modelData
                                Accessible.checked: on
                                Rectangle { anchors.centerIn: parent; width: 20; height: 20; radius: 10; color: parent.modelData }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: panel.setColour(accentGroup.modelData.role, parent.modelData) }
                            }
                        }
                        IconButton {
                            iconName: "reload"; iconSize: 14; iconColor: Theme.dim
                            tip: qsTr("Theme's own colour")
                            onClicked: Browser.resetSetting("appearance/custom/" + Theme.preset + "/" + accentGroup.modelData.role)
                        }
                    }
                }
            }
            Text { text: qsTr("Tabs"); color: Theme.dim; font.pixelSize: Theme.px(12) }
            Ui.Segmented {
                options: [{ label: qsTr("Pill"), value: "pill" }, { label: qsTr("Square"), value: "square" }, { label: qsTr("Line"), value: "line" }]
                value: Theme.tabStyle
                onPicked: (v) => panel.set("tabs/style", v)
            }
            Text { text: qsTr("Corners"); color: Theme.dim; font.pixelSize: Theme.px(12) }
            Ui.Slide { Layout.fillWidth: true; from: 0; to: 16; stepSize: 1; value: Theme.radius; onMoved: panel.set("appearance/roundness", value) }
            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Bookmarks bar"); color: Theme.fg; font.pixelSize: Theme.px(13); Layout.fillWidth: true }
                Ui.Toggle { checked: Theme.showBookmarksBar; onToggled: panel.set("layout/bookmarksBar", checked) }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Tabs on the right"); color: Theme.fg; font.pixelSize: Theme.px(13); Layout.fillWidth: true }
                Ui.Toggle { checked: Theme.tabsOnRight; onToggled: panel.set("layout/tabsSide", checked ? "right" : "left") }
            }
            Ui.Pill { primary: true; text: qsTr("Open Appearance Studio"); onClicked: panel.studioRequested() }
        }
    }
}
