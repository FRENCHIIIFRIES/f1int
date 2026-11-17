import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import f1int

// The menu under the profile picture: who you are here, your other profiles (each opens in
// its own window, with its own bookmarks, history, passwords and settings), and accounts.
Popup {
    id: menu
    signal manageRequested()
    width: 300
    padding: 14
    background: Rectangle { color: Theme.surface; radius: Theme.cardRadius; border.width: 1; border.color: Theme.line }

    contentItem: ColumnLayout {
        spacing: 10
        RowLayout {
            spacing: 12
            Ui.Avatar { width: 44; height: 44; name: Browser.profiles.currentName; picture: Browser.profiles.currentPicture }
            Column {
                Layout.fillWidth: true
                Text { text: Browser.profiles.currentName; color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
                Text { text: qsTr("Local profile · stored on this computer"); color: Theme.dim; font.pixelSize: Theme.px(11) }
            }
        }
        Rectangle {   // account status
            Layout.fillWidth: true
            implicitHeight: accountText.implicitHeight + 20
            radius: Theme.radius
            color: Theme.field
            Text {
                id: accountText
                x: 10; y: 10
                width: parent.width - 20
                wrapMode: Text.WordWrap
                text: qsTr("Not signed in to an f1int account. Sync between computers isn't available yet.")
                color: Theme.dim
                font.pixelSize: Theme.px(11)
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line }
        Text { text: qsTr("Other profiles"); color: Theme.dim; font.pixelSize: Theme.px(11); visible: others.count > 0 }
        Repeater {
            id: others
            model: Browser.profiles.list.filter(p => !p.current)
            Rectangle {
                id: other
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: Theme.radius
                color: otherHover.hovered ? Theme.hover : "transparent"
                HoverHandler { id: otherHover; cursorShape: Qt.PointingHandCursor }
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Open %1").arg(other.modelData.name)
                Ui.Avatar { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; name: other.modelData.name; picture: other.modelData.picture }
                Text { x: 42; anchors.verticalCenter: parent.verticalCenter; text: other.modelData.name; color: Theme.fg; font.pixelSize: Theme.px(13) }
                MouseArea { anchors.fill: parent; onClicked: { Browser.profiles.open(other.modelData.id); menu.close() } }
            }
        }
        RowLayout {
            spacing: 8
            Ui.Pill {
                text: qsTr("Add profile")
                onClicked: { Browser.profiles.open(Browser.profiles.add("")); menu.close() }
            }
            Ui.Pill { text: qsTr("Manage"); onClicked: { menu.manageRequested(); menu.close() } }
        }
    }
}
