import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import f1int

// Settings > Extensions: Chrome extensions through Qt WebEngine's extension support.
// Add one from an unpacked folder or a .zip; switch it on or off; remove it.
ColumnLayout {
    id: ext
    signal openUrl(url url)          // an extension's popup page, opened in a tab
    spacing: 22
    readonly property var manager: Browser.profile.extensionManager
    property var list: manager ? manager.extensions : []
    property string message: ""
    function refresh() { list = manager ? manager.extensions : [] }
    function done(info, verb) { refresh(); message = info.error ? qsTr("%1: %2").arg(info.name || qsTr("Extension")).arg(info.error) : qsTr("%1 %2.").arg(info.name).arg(verb) }
    Connections {
        target: Browser
        function onWebStoreFailed(id, error) { ext.message = error }
        function onExtensionAdded(name, error) { ext.refresh(); ext.message = error ? qsTr("%1: %2").arg(name || qsTr("Extension")).arg(error) : qsTr("%1 added.").arg(name) }
    }
    Connections {
        target: ext.manager
        function onInstallFinished(info) { ext.done(info, qsTr("added")) }
        function onLoadFinished(info) { ext.done(info, qsTr("loaded")) }
        function onUninstallFinished(info) { ext.done(info, qsTr("removed")) }
        function onUnloadFinished(info) { ext.refresh() }
    }

    Ui.Section {
        title: qsTr("Your extensions")
        Ui.SettingRow {
            visible: ext.list.length === 0
            label: qsTr("No extensions yet")
            hint: qsTr("Add one below")
            last: true
        }
        Repeater {
            model: ext.list
            Ui.SettingRow {
                id: extRow
                required property var modelData
                required property int index
                label: modelData.name
                hint: modelData.error ? modelData.error : modelData.description
                last: index === ext.list.length - 1
                Row {
                    spacing: 6
                    Ui.Pill {
                        visible: String(extRow.modelData.actionPopupUrl) !== ""
                        text: qsTr("Open")
                        onClicked: ext.openUrl(extRow.modelData.actionPopupUrl)
                    }
                    Ui.Toggle {
                        checked: extRow.modelData.isEnabled
                        onToggled: { ext.manager.setExtensionEnabled(extRow.modelData, checked); ext.refresh() }
                        anchors.verticalCenter: parent.verticalCenter
                        Accessible.name: qsTr("Enabled")
                    }
                    IconButton {
                        iconName: "trash"
                        iconColor: Theme.dim
                        tip: qsTr("Remove")
                        onClicked: extRow.modelData.isInstalled ? ext.manager.uninstallExtension(extRow.modelData)
                                                                               : ext.manager.unloadExtension(extRow.modelData)
                    }
                }
            }
        }
    }
    Ui.Section {
        title: qsTr("Add an extension")
        Ui.SettingRow {
            label: qsTr("From the Chrome Web Store")
            hint: qsTr("Open an extension's page in the store and press \"Add to f1int\", or paste its link here")
            Row {
                spacing: 8
                Ui.Field { id: storeLink; width: 220; placeholderText: qsTr("chromewebstore.google.com/detail/…"); onAccepted: addStore.clicked() }
                Ui.Pill {
                    id: addStore
                    text: qsTr("Add")
                    enabled: Browser.webStoreId(Browser.urlFromInput(storeLink.text)) !== ""
                    onClicked: { Browser.installFromWebStore(Browser.webStoreId(Browser.urlFromInput(storeLink.text))); storeLink.text = ""; ext.message = qsTr("Adding…") }
                }
            }
        }
        Ui.SettingRow {
            label: qsTr("From a folder")
            hint: qsTr("An unpacked extension (the folder with manifest.json)")
            Ui.Pill { text: qsTr("Choose folder…"); onClicked: folderDialog.open() }
        }
        Ui.SettingRow {
            label: qsTr("From a .zip file")
            last: true
            Ui.Pill { text: qsTr("Choose file…"); onClicked: zipDialog.open() }
        }
    }
    Text { visible: ext.message !== ""; text: ext.message; color: Theme.fg; font.pixelSize: Theme.px(13) }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Theme.dim
        font.pixelSize: Theme.px(12)
        text: qsTr("f1int runs Chrome extensions through Qt WebEngine, which supports many, not all, of their features: simple ones (ad blockers, dark mode, page tools) work best.")
    }
    FolderDialog { id: folderDialog; onAccepted: ext.manager.installExtension(Browser.localPath(selectedFolder)) }
    FileDialog { id: zipDialog; nameFilters: [qsTr("Extensions (*.zip)")]; onAccepted: ext.manager.installExtension(Browser.localPath(selectedFile)) }
}
