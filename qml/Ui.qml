import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import f1int

// Small building blocks in f1int's style, shared by the panels and settings.
// Use them as Ui.Toggle, Ui.Field, Ui.Pill, Ui.Segmented, Ui.Section, Ui.SettingRow.
QtObject {
    // Panel and dialog titles: dot-matrix, sentence case.
    component Heading: Text {
        color: Theme.fg
        font.pixelSize: Theme.px(20)
        font.weight: Font.DemiBold
    }

    // A profile's picture, or its first letter on the accent colour.
    component Avatar: Rectangle {
        property string name
        property url picture
        implicitWidth: 28
        implicitHeight: 28
        radius: width / 2
        color: picture.toString() !== "" ? "transparent" : Theme.accent
        Text {
            anchors.centerIn: parent
            visible: parent.picture.toString() === ""
            text: (parent.name || "?").charAt(0).toUpperCase()
            color: Theme.textOnAccent
            font.pixelSize: Math.round(parent.width * 0.45)
            font.weight: Font.DemiBold
        }
        Image {
            anchors.fill: parent
            visible: parent.picture.toString() !== ""
            source: parent.picture
            sourceSize: Qt.size(128, 128)
            cache: false
        }
    }

    // A small outlined tag, e.g. "weak" next to a password.
    component Badge: Rectangle {
        property alias text: badgeText.text
        implicitWidth: badgeText.implicitWidth + 12
        implicitHeight: 18
        radius: 9
        color: "transparent"
        border.width: 1
        border.color: Theme.accent
        Text { id: badgeText; anchors.centerIn: parent; color: Theme.accent; font.pixelSize: Theme.px(10) }
    }

    // A hidden secret shown as a row of round dots (dot-matrix style).
    component Dots: Row {
        property int count: 10
        property color color: Theme.dim
        spacing: 3
        Repeater {
            model: parent.count
            Rectangle { width: 5; height: 5; radius: 2.5; color: parent.color; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // A slider: thin track, the filled part in the accent colour, round handle.
    component Slide: Slider {
        id: slide
        implicitWidth: 160
        implicitHeight: 24
        background: Rectangle {
            x: slide.leftPadding
            y: slide.topPadding + slide.availableHeight / 2 - height / 2
            width: slide.availableWidth
            height: 4
            radius: 2
            color: Theme.field
            Rectangle { width: slide.visualPosition * parent.width; height: parent.height; radius: 2; color: Theme.accent }
        }
        handle: Rectangle {
            x: slide.leftPadding + slide.visualPosition * (slide.availableWidth - width)
            y: slide.topPadding + slide.availableHeight / 2 - height / 2
            width: 16
            height: 16
            radius: 8
            color: "#ffffff"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.15)
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

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
                // White knob on the accent colour (dark knob only on a very light accent).
                color: toggle.checked ? (Theme.accent.hslLightness > 0.7 ? "#000000" : "#ffffff") : Theme.fg
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
        selectedTextColor: Theme.textOnAccent
        selectByMouse: true
        font.pixelSize: Theme.px(13)
        leftPadding: 12
        background: Rectangle {
            radius: Theme.radius
            color: Theme.field
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
            color: pill.primary ? Theme.textOnAccent : (pill.enabled ? Theme.fg : Theme.dim)
            font.pixelSize: Theme.px(12)
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
        radius: Math.min(15, Theme.radius + 4)
        color: Theme.field
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
                    radius: Math.min(12, Theme.radius + 2)
                    // The picked choice is a soft raised pill (calm), not a loud accent fill.
                    color: on ? Theme.tab : hover.hovered ? Theme.hover : "transparent"
                    border.width: on ? 1 : 0
                    border.color: Theme.line
                    Behavior on color { ColorAnimation { duration: Theme.anim } }
                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.label
                    Accessible.checked: on
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: parent.on ? Theme.fg : Theme.dim
                        font.pixelSize: Theme.px(12)
                        font.weight: parent.on ? Font.Medium : Font.Normal
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
        // While searching settings, a group with no matching rows hides.
        visible: Theme.settingsFilter === "" || box.visibleChildren.length > 0
        spacing: 8
        Text {
            text: parent.title
            color: Theme.dim
            font.pixelSize: Theme.px(12)
            Layout.leftMargin: 4
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: box.implicitHeight
            radius: Theme.cardRadius
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
        visible: Theme.settingsFilter === "" || (label + " " + hint).toLowerCase().indexOf(Theme.settingsFilter) >= 0
        implicitHeight: Math.max(48, labels.implicitHeight + 24, slot.childrenRect.height + 20)
        ColumnLayout {
            id: labels
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: slot.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { text: settingRow.label; color: Theme.fg; font.pixelSize: Theme.px(13); Layout.fillWidth: true; wrapMode: Text.Wrap }
            Text { visible: settingRow.hint !== ""; text: settingRow.hint; color: Theme.dim; font.pixelSize: Theme.px(11); Layout.fillWidth: true; wrapMode: Text.Wrap }
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
