import QtQuick
import QtQuick.Controls.Basic
import f1int

// "Rename bookmark": a small box with the name ready to change. openFor({ url, title }).
Popup {
    id: box
    property var bookmark: null
    function openFor(b) { bookmark = b; field.text = b.title || ""; open(); field.forceActiveFocus(); field.selectAll() }
    function save() {
        // An empty name is allowed: the bookmarks bar then shows just the site's logo.
        Browser.library.renameBookmark(bookmark.url, field.text.trim().slice(0, 200))
        close()
    }
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    padding: 18
    background: Rectangle { color: Theme.surface; radius: Theme.cardRadius; border.width: 1; border.color: Theme.line }
    contentItem: Column {
        spacing: 12
        Text { text: qsTr("Rename bookmark"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold }
        Text {
            width: 300
            text: box.bookmark ? String(box.bookmark.url).replace(/^https?:\/\/(www\.)?/, "") : ""
            color: Theme.dim
            font.pixelSize: Theme.px(12)
            elide: Text.ElideMiddle
        }
        Ui.Field { id: field; width: 300; maximumLength: 200; placeholderText: qsTr("No name: just the logo"); Accessible.name: qsTr("Bookmark name"); onAccepted: box.save() }
        Row {
            spacing: 8
            Ui.Pill { primary: true; text: qsTr("Save"); onClicked: box.save() }
            Ui.Pill { text: qsTr("Cancel"); onClicked: box.close() }
        }
    }
}
