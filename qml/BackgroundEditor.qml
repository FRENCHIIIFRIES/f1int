import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import f1int

// Appearance > Backgrounds: for the window, the tab column and the toolbar, a plain colour,
// a gradient, your own picture or a pattern, with fitting, position, dimming, blur and
// see-through. Stored per theme preset (Theme.fill / Theme.setFill).
ColumnLayout {
    id: editor
    property var picker: null          // the studio's colour popup (pick(colour, callback))
    property string message: ""
    spacing: 22

    Repeater {
        model: [{ surface: "window", label: qsTr("Window background"), hint: qsTr("Behind everything: shows around the page, and through the tab column and toolbar when they're see-through") },
                { surface: "sidebar", label: qsTr("Tab column"), hint: qsTr("Also behind the tabs") },
                { surface: "toolbar", label: qsTr("Toolbar"), hint: qsTr("The address bar and bookmarks bar") }]
        Ui.Section {
            id: section
            required property var modelData
            readonly property string surface: modelData.surface
            readonly property var f: { void Browser.settingsRevision; return Theme.fill(section.surface) }
            function change(c) { Theme.setFill(section.surface, c) }
            title: modelData.label
            Ui.SettingRow {
                label: qsTr("Style")
                hint: section.modelData.hint
                Ui.Segmented {
                    options: [{ label: qsTr("Colour"), value: "solid" }, { label: qsTr("Gradient"), value: "gradient" },
                              { label: qsTr("Picture"), value: "image" }, { label: qsTr("Pattern"), value: "pattern" }]
                    value: section.f.type
                    onPicked: (v) => section.change({ type: v })
                }
            }

            // ---- gradient: two or three colours and an angle ----
            Ui.SettingRow {
                visible: section.f.type === "gradient"
                label: qsTr("Colours")
                hint: qsTr("Click one to change it")
                Row {
                    spacing: 6
                    Repeater {
                        model: section.f.colors.length >= 2 ? section.f.colors : [String(Theme.role(section.surface === "window" ? "frame" : section.surface)), "#6e4aff"]
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: 30; height: 30; radius: 15
                            color: modelData
                            border.width: 1; border.color: Theme.line
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            Accessible.role: Accessible.Button
                            Accessible.name: qsTr("Gradient colour %1").arg(index + 1)
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    const list = section.f.colors.length >= 2 ? section.f.colors.slice() : [String(Theme.role(section.surface === "window" ? "frame" : section.surface)), "#6e4aff"]
                                    editor.picker.pick(parent.modelData, (c) => { list[parent.index] = c; section.change({ colors: list }) })
                                }
                            }
                        }
                    }
                    IconButton {
                        visible: section.f.colors.length < 3
                        iconName: "plus"; iconSize: 14; tip: qsTr("Add a middle colour")
                        onClicked: { const l = section.f.colors.length >= 2 ? section.f.colors.slice() : [String(Theme.chromeSolid), "#6e4aff"]; l.splice(1, 0, String(Theme.accent)); section.change({ colors: l.slice(0, 3) }) }
                    }
                    IconButton {
                        visible: section.f.colors.length > 2
                        iconName: "close"; iconSize: 14; tip: qsTr("Remove the middle colour")
                        onClicked: { const l = section.f.colors.slice(); l.splice(1, 1); section.change({ colors: l }) }
                    }
                }
            }
            Ui.SettingRow {
                visible: section.f.type === "gradient"
                label: qsTr("Direction")
                Row {
                    spacing: 10
                    Ui.Slide { width: 160; from: 0; to: 360; stepSize: 5; value: section.f.angle; onMoved: section.change({ angle: value }) }
                    Text { text: Math.round(section.f.angle) + "°"; color: Theme.dim; font.family: Theme.numberFont; font.pixelSize: Theme.px(12); anchors.verticalCenter: parent.verticalCenter }
                }
            }

            // ---- picture ----
            Ui.SettingRow {
                visible: section.f.type === "image"
                label: qsTr("Picture")
                hint: section.f.image === "" ? qsTr("PNG, JPG, WEBP, GIF or SVG") : qsTr("Your picture is stored in f1int, checked and cleaned")
                Row {
                    spacing: 8
                    Image {
                        visible: section.f.image !== ""
                        width: 56; height: 34
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(112, 68)
                        source: Browser.assets.url(section.f.image)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Ui.Pill { text: section.f.image === "" ? qsTr("Choose…") : qsTr("Change…"); onClicked: { pictureDialog.section = section; pictureDialog.open() } }
                }
            }
            Ui.SettingRow {
                visible: section.f.type === "image"
                label: qsTr("Fit")
                Ui.Segmented {
                    options: [{ label: qsTr("Fill"), value: "fill" }, { label: qsTr("Fit"), value: "fit" }, { label: qsTr("Stretch"), value: "stretch" },
                              { label: qsTr("Tile"), value: "tile" }, { label: qsTr("Centre"), value: "center" }]
                    value: section.f.fit
                    onPicked: (v) => section.change({ fit: v })
                }
            }
            Ui.SettingRow {
                visible: section.f.type === "image" && section.f.fit !== "stretch" && section.f.fit !== "tile"
                label: qsTr("Position")
                Ui.Segmented {
                    options: [{ label: qsTr("Centre"), value: "center" }, { label: qsTr("Top"), value: "top" }, { label: qsTr("Bottom"), value: "bottom" },
                              { label: qsTr("Left"), value: "left" }, { label: qsTr("Right"), value: "right" }]
                    value: section.f.position
                    onPicked: (v) => section.change({ position: v })
                }
            }
            Ui.SettingRow {
                visible: section.f.type === "image"
                label: qsTr("Darken")
                hint: qsTr("Keeps text on top readable")
                Ui.Slide { width: 160; from: 0; to: 0.9; value: section.f.dim; onMoved: section.change({ dim: Math.round(value * 100) / 100 }) }
            }
            Ui.SettingRow {
                visible: section.f.type === "image"
                label: qsTr("Blur")
                Ui.Slide { width: 160; from: 0; to: 1; value: section.f.blur; onMoved: section.change({ blur: Math.round(value * 100) / 100 }) }
            }

            // ---- pattern ----
            Ui.SettingRow {
                visible: section.f.type === "pattern"
                label: qsTr("Pattern")
                Ui.Segmented {
                    options: [{ label: qsTr("Dots"), value: "dots" }, { label: qsTr("Grid"), value: "grid" }, { label: qsTr("Lines"), value: "lines" },
                              { label: qsTr("Diagonal"), value: "diagonal" }, { label: qsTr("Waves"), value: "waves" }, { label: qsTr("Cross"), value: "cross" }]
                    value: section.f.pattern
                    onPicked: (v) => section.change({ pattern: v })
                }
            }
            Ui.SettingRow {
                visible: section.f.type === "pattern"
                label: qsTr("Size")
                Ui.Slide { width: 160; from: 0.5; to: 3; value: section.f.patternScale; onMoved: section.change({ patternScale: Math.round(value * 10) / 10 }) }
            }
            Ui.SettingRow {
                visible: section.f.type === "pattern"
                label: qsTr("Strength")
                Row {
                    spacing: 8
                    Ui.Slide { width: 160; from: 0.03; to: 0.6; value: section.f.patternOpacity; onMoved: section.change({ patternOpacity: Math.round(value * 100) / 100 }) }
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: section.f.patternColor !== "" ? section.f.patternColor : Theme.fg
                        border.width: 1; border.color: Theme.line
                        anchors.verticalCenter: parent.verticalCenter
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Pattern colour")
                        MouseArea { anchors.fill: parent; onClicked: editor.picker.pick(section.f.patternColor || String(Theme.fg), (c) => section.change({ patternColor: c })) }
                    }
                }
            }

            // ---- see-through (not for the window itself) ----
            Ui.SettingRow {
                visible: section.surface !== "window"
                label: qsTr("See-through")
                hint: qsTr("Lets the window background show through")
                Ui.Slide { width: 160; from: 0; to: 0.8; value: 1 - section.f.opacity; onMoved: section.change({ opacity: Math.round((1 - value) * 100) / 100 }) }
            }
            Ui.SettingRow {
                label: qsTr("Back to the theme's own")
                last: true
                Ui.Pill { text: qsTr("Reset"); onClicked: Browser.resetSetting("appearance/fill/" + Theme.preset + "/" + section.surface) }
            }
        }
    }
    Text {
        visible: editor.message !== ""
        text: editor.message
        color: Theme.accent2
        font.pixelSize: Theme.px(12)
    }
    FileDialog {
        id: pictureDialog
        property var section: null
        nameFilters: [qsTr("Pictures (*.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg)")]
        onAccepted: {
            const r = Browser.assets.add(selectedFile, "image")
            editor.message = r.ok ? "" : r.error
            if (r.ok) section.change({ type: "image", image: r.id })
        }
    }
}
