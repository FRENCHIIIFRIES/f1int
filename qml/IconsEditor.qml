import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import f1int

// Appearance > Icons and motion: icon weight, your own icon pack, and the loading animation.
ColumnLayout {
    id: editor
    property string message: ""
    spacing: 22
    readonly property var sample: ["back", "reload", "home", "star", "history", "download", "key", "settings", "search", "sidebar"]

    Ui.Section {
        title: qsTr("Icons")
        Item {   // what they look like now
            Layout.fillWidth: true
            implicitHeight: 56
            Row {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
                Repeater {
                    model: editor.sample
                    Icon { required property string modelData; glyph: modelData; sourceSize: Qt.size(20, 20) }
                }
            }
        }
        Ui.SettingRow {
            label: qsTr("Line weight")
            hint: qsTr("Thin and airy, or bold")
            Row {
                spacing: 10
                Ui.Slide { width: 160; from: 0.75; to: 3; stepSize: 0.25; value: Theme.iconWeight; onMoved: Browser.setSetting("appearance/iconWeight", value) }
                Text { text: Theme.iconWeight.toFixed(2); color: Theme.dim; font.family: Theme.numberFont; font.pixelSize: Theme.px(12); anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Ui.SettingRow {
            label: qsTr("Your own icons")
            hint: Object.keys(Theme.iconMap).length > 0
                  ? qsTr("%1 icons replaced").arg(Object.keys(Theme.iconMap).length)
                  : qsTr("Choose SVG files named like f1int's icons (star.svg, home.svg, back.svg…). Only drawings are kept: scripts and links are removed.")
            Row {
                spacing: 8
                Ui.Pill { text: qsTr("Choose SVGs…"); onClicked: iconDialog.open() }
                Ui.Pill { visible: Object.keys(Theme.iconMap).length > 0; text: qsTr("Remove"); onClicked: Browser.resetSetting("appearance/icons") }
            }
        }
        Ui.SettingRow {
            label: qsTr("Icon names")
            hint: Browser.assets.iconNames.join(", ")
            last: true
        }
    }
    Ui.Section {
        title: qsTr("Loading animation")
        Ui.SettingRow {
            label: qsTr("Style")
            hint: qsTr("In tabs and while importing or syncing")
            Row {
                spacing: 14
                DotLoader { anchors.verticalCenter: parent.verticalCenter }
                Ui.Segmented {
                    options: [{ label: qsTr("Dots"), value: "dots" }, { label: qsTr("Spinner"), value: "spinner" }, { label: qsTr("Pulse"), value: "pulse" },
                              { label: qsTr("Bar"), value: "bar" }, { label: qsTr("Your own"), value: "image" }]
                    value: Theme.loaderStyle
                    onPicked: (v) => v === "image" && Theme.loaderImage === "" ? loaderDialog.open() : Browser.setSetting("appearance/loader", v)
                }
            }
        }
        Ui.SettingRow {
            visible: Theme.loaderStyle === "image"
            label: qsTr("Your animation")
            hint: qsTr("A GIF or animated WEBP (a still picture works too), up to 4 MB")
            last: true
            Ui.Pill { text: qsTr("Change…"); onClicked: loaderDialog.open() }
        }
    }
    Text { visible: editor.message !== ""; text: editor.message; color: Theme.fg; font.pixelSize: Theme.px(12) }

    FileDialog {
        id: iconDialog
        fileMode: FileDialog.OpenFiles
        nameFilters: [qsTr("SVG drawings (*.svg)")]
        onAccepted: {
            const r = Browser.assets.addIcons(selectedFiles)
            Browser.setSetting("appearance/icons", JSON.stringify(Object.assign({}, Theme.iconMap, r.icons)))
            editor.message = qsTr("%1 icons added.").arg(r.added) + (r.skipped.length ? " " + qsTr("Skipped: %1").arg(r.skipped.join(", ")) : "")
        }
    }
    FileDialog {
        id: loaderDialog
        nameFilters: [qsTr("Animations and pictures (*.gif *.webp *.png *.svg)")]
        onAccepted: {
            const r = Browser.assets.add(selectedFile, "loader")
            editor.message = r.ok ? "" : r.error
            if (r.ok) { Browser.setSetting("appearance/loaderImage", r.id); Browser.setSetting("appearance/loader", "image") }
        }
    }
}
