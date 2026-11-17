import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import f1int

// Small building blocks in f1int's style, shared by the panels and settings.
// Use them as Ui.Toggle, Ui.Field, Ui.Pill, Ui.Segmented, Ui.Section, Ui.SettingRow.
QtObject {
    // On/off switch, like a phone's.
    component Toggle: Switch {
        id: toggle
        implicitWidth: 44
        implicitHeight: 26
        padding: 0
        indicator: Rectangle {
            implicitWidth: 44
            implicitHeight: 26
            radius: 13
            color: toggle.checked ? Theme.accent : Theme.press
            Behavior on color { ColorAnimation { duration: Theme.anim } }
            Rectangle {
                width: 20
                height: 20
                radius: 10
                y: 3
                x: toggle.checked ? parent.width - width - 3 : 3
                color: toggle.checked ? Theme.onAccent : Theme.fg
                Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            }
        }
        contentItem: Item {}
    }

    // Text box with a thin border.
    component Field: TextField {
        id: field
        implicitHeight: 32
        color: Theme.fg
        placeholderTextColor: Theme.dim
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccent
        selectByMouse: true
        font.pixelSize: 13
        leftPadding: 12
        background: Rectangle {
            radius: 8
            color: Theme.bg
            border.width: 1
            border.color: field.activeFocus ? Theme.dim : Theme.line
        }
    }

    // Rounded button; `primary` fills it with the accent colour.
    component Pill: Button {
        id: pill
        property bool primary: false
        implicitHeight: 30
        leftPadding: 14
        rightPadding: 14
        contentItem: Text {
            text: pill.text
            color: pill.primary ? Theme.onAccent : (pill.enabled ? Theme.fg : Theme.dim)
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            implicitWidth: 72
            radius: 15
            color: pill.primary ? (pill.down ? Qt.darker(Theme.accent, 1.2) : Theme.accent)
                                : (pill.down ? Theme.press : pill.hovered ? Theme.hover : "transparent")
            border.width: pill.primary ? 0 : 1
            border.color: Theme.line
        }
    }

    // A row of choices where one is picked, e.g. Dark | Light | System.
    component Segmented: Rectangle {
        id: seg
        property var options: []     // [{ label, value }]
        property var value
        signal picked(var value)
        implicitWidth: row.implicitWidth + 6
        implicitHeight: 30
        radius: 15
        color: Theme.bg
        border.width: 1
        border.color: Theme.line
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: seg.options
                Rectangle {
                    required property var modelData
                    readonly property bool on: seg.value === modelData.value
                    width: label.implicitWidth + 22
                    height: 24
                    radius: 12
                    color: on ? Theme.accent : hover.hovered ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.anim } }
                    HoverHandler { id: hover }
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.label
                    Accessible.checked: on
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: parent.on ? Theme.onAccent : Theme.fg
                        font.pixelSize: 12
                    }
                    MouseArea { anchors.fill: parent; onClicked: seg.picked(parent.modelData.value) }
                }
            }
        }
    }

    // A settings group: small title, then a rounded box holding rows (phone-settings style).
    component Section: ColumnLayout {
        property string title
        default property alias rows: box.data
        Layout.fillWidth: true
        spacing: 8
        Text {
            text: parent.title.toUpperCase()
            color: Theme.dim
            font.pixelSize: 11
            font.letterSpacing: 1.5
            Layout.leftMargin: 4
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: box.implicitHeight
            radius: 14
            color: Theme.surface
            border.width: 1
            border.color: Theme.line
            ColumnLayout {
                id: box
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0
            }
        }
    }

    // One line in a settings group: label (and hint) on the left, a control on the right.
    component SettingRow: Item {
        id: settingRow
        property string label
        property string hint
        property bool last: false
        default property alias control: slot.data
        Layout.fillWidth: true
        implicitHeight: Math.max(48, labels.implicitHeight + 24, slot.childrenRect.height + 20)
        ColumnLayout {
            id: labels
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: slot.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { text: settingRow.label; color: Theme.fg; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.Wrap }
            Text { visible: settingRow.hint !== ""; text: settingRow.hint; color: Theme.dim; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.Wrap }
        }
        Item {
            id: slot
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
        Rectangle {   // thin divider between rows
            visible: !settingRow.last
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            height: 1
            color: Theme.line
        }
    }
}
