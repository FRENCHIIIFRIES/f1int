import QtQuick
import QtQuick.Controls.Basic
import f1int

// Bookmarks under the address bar (Ctrl+Shift+B shows or hides it). Click opens in this tab,
// middle-click or Ctrl+click in a new one, right-click removes. What doesn't fit goes in ».
Item {
    id: bar
    signal open(url url, bool background)
    readonly property var items: { void Browser.library.revision; return Browser.library.bookmarks().slice(0, 60) }

    Row {
        id: row
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Repeater {
            model: bar.items
            Rectangle {
                id: chip
                required property var modelData
                required property int index
                // Only chips that fit before the » button are shown.
                visible: x + width <= bar.width - 48
                width: Math.min(170, label.implicitWidth + 38)
                height: 26
                radius: Math.min(Theme.radius, 8)
                color: chipMouse.pressed ? Theme.press : chipMouse.containsMouse && Theme.hoverEffects ? Theme.hover : "transparent"
                Image {
                    id: fav
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    sourceSize: Qt.size(16, 16)
                    source: { void Browser.favicons.revision; return Browser.favicons.icon(chip.modelData.url) }
                    visible: status === Image.Ready && implicitWidth > 0
                }
                Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; glyph: "globe"; sourceSize: Qt.size(14, 14); color: Theme.dim; visible: !fav.visible }
                Text {
                    id: label
                    x: 28
                    width: parent.width - 34
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.title || String(chip.modelData.url).replace(/^https?:\/\/(www\.)?/, "")
                    color: Theme.fg
                    font.pixelSize: Theme.px(12)
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: (m) => {
                        if (m.button === Qt.RightButton) { menu.target = chip.modelData; menu.popup() }
                        else bar.open(chip.modelData.url, m.button === Qt.MiddleButton || (m.modifiers & Qt.ControlModifier))
                    }
                }
                ToolTip.visible: chipMouse.containsMouse
                ToolTip.delay: 700
                ToolTip.text: String(chip.modelData.url)
            }
        }
    }
    Text {   // empty: say how to fill it
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        visible: bar.items.length === 0
        text: qsTr("Bookmark pages with the star (Ctrl+D) and they appear here")
        color: Theme.dim
        font.pixelSize: Theme.px(12)
    }
    IconButton {   // everything that didn't fit
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 26
        implicitHeight: 26
        visible: bar.items.length > 0 && row.childrenRect.width > bar.width - 56
        iconName: "chevron"
        iconSize: 14
        iconColor: Theme.dim
        tip: qsTr("More bookmarks")
        onClicked: overflow.popup(this, 0, height + 4)
    }
    F1Menu {
        id: overflow
        Repeater {
            model: bar.items
            MenuItem {
                required property var modelData
                text: modelData.title || String(modelData.url)
                onTriggered: bar.open(modelData.url, false)
            }
        }
    }
    RenameBookmark { id: renameBox }
    F1Menu {
        id: menu
        property var target: null
        MenuItem { text: qsTr("Open in new tab"); onTriggered: bar.open(menu.target.url, true) }
        MenuItem { text: qsTr("Rename…"); onTriggered: renameBox.openFor(menu.target) }
        MenuItem { text: qsTr("Remove bookmark"); onTriggered: Browser.library.removeBookmark(menu.target.url) }
    }
}
