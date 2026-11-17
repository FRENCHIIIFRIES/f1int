import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import f1int

// The password manager: set up, unlock, and manage saved logins.
// Everything here stays on this computer; nothing is ever sent over the network.
Rectangle {
    id: panel
    signal closeRequested()
    readonly property var vault: Browser.passwords
    readonly property string deviceName: Qt.platform.os === "osx" ? "Touch ID" : "Windows Hello"
    property string message: ""         // errors and confirmations
    property string revealedId: ""      // the one login whose password is shown
    property string revealed: ""
    property string pendingRevealId: "" // waiting for "is it you?" before showing
    property string editingId: ""       // "" = none, "new" = adding

    readonly property var rows: { void vault.revision; return vault.state === "unlocked" ? vault.entries(search.text) : [] }
    readonly property var health: { void vault.revision; return vault.state === "unlocked" ? vault.health() : ({ weak: 0, reused: 0 }) }

    function host(origin) { return origin.replace(/^https?:\/\/(www\.)?/, "") }
    function show(id) {
        if (revealedId === id) { revealedId = ""; revealed = ""; return }
        if (vault.recentlyVerified()) { revealedId = id; revealed = vault.reveal(id); return }
        pendingRevealId = id
        if (vault.deviceUnlock) Browser.askDevice(Window.window, "verify")
        else verifyPopup.open()
    }

    color: Theme.surface
    Rectangle { width: 1; height: parent.height; color: Theme.line }

    Connections {
        target: Browser
        function onDeviceAuthFinished(purpose, ok, error) {
            if (purpose === "verify" && ok && panel.pendingRevealId !== "") {
                panel.revealedId = panel.pendingRevealId; panel.revealed = panel.vault.reveal(panel.pendingRevealId)
            }
            panel.pendingRevealId = ""
            panel.message = ok ? "" : error
        }
    }
    Timer { running: panel.revealedId !== ""; interval: 30000; onTriggered: { panel.revealedId = ""; panel.revealed = "" } }   // hide again

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Ui.Heading { text: qsTr("Passwords") }
            Text {
                visible: panel.vault.state === "unlocked"
                text: panel.rows.length
                color: Theme.dim
                font.family: Theme.numberFont
                font.pixelSize: Theme.px(20)
                font.weight: Font.Bold
            }
            Item { Layout.fillWidth: true }
            IconButton {
                visible: panel.vault.state === "unlocked"
                iconName: "lock"
                tip: qsTr("Lock passwords")
                onClicked: panel.vault.lock()
            }
            IconButton { iconName: "close"; tip: qsTr("Close"); onClicked: panel.closeRequested() }
        }
        Text {
            visible: panel.message !== ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: panel.message
            color: Theme.accent
            font.pixelSize: Theme.px(12)
        }

        // ---------- first time: create the vault ----------
        ColumnLayout {
            visible: panel.vault.state === "none"
            Layout.fillWidth: true
            spacing: 12
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.fg
                font.pixelSize: Theme.px(13)
                text: qsTr("Choose a master password. Your passwords are encrypted with it (AES-256) and stay on this computer; nothing is sent anywhere.")
            }
            Ui.Field { id: setupPassword; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: qsTr("Master password (at least 8 characters)") }
            Ui.Field { id: setupRepeat; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: qsTr("Repeat it"); onAccepted: create.clicked() }
            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Also unlock with %1").arg(panel.deviceName); color: Theme.fg; font.pixelSize: Theme.px(13); Layout.fillWidth: true }
                Ui.Toggle { id: setupDevice; checked: true }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.dim
                font.pixelSize: Theme.px(11)
                text: qsTr("If you forget the master password it can't be recovered (but %1 keeps working if it's on).").arg(panel.deviceName)
            }
            Ui.Pill {
                id: create
                primary: true
                text: qsTr("Create password vault")
                onClicked: {
                    if (setupPassword.text.length < 8) panel.message = qsTr("The master password needs at least 8 characters.")
                    else if (setupPassword.text !== setupRepeat.text) panel.message = qsTr("The two passwords don't match.")
                    else if (panel.vault.setUp(setupPassword.text, setupDevice.checked)) { panel.message = ""; setupPassword.text = ""; setupRepeat.text = "" }
                    else panel.message = qsTr("Couldn't create the vault.")
                }
            }
        }

        // ---------- locked ----------
        ColumnLayout {
            visible: panel.vault.state === "locked"
            Layout.fillWidth: true
            spacing: 12
            Icon { glyph: "lock"; sourceSize: Qt.size(40, 40); Layout.alignment: Qt.AlignHCenter; color: Theme.dim }
            Ui.Pill {
                visible: panel.vault.deviceUnlock
                Layout.fillWidth: true
                primary: true
                text: qsTr("Unlock with %1").arg(panel.deviceName)
                onClicked: Browser.askDevice(Window.window, "unlock")
            }
            Ui.Field {
                id: unlockPassword
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: qsTr("Master password")
                onAccepted: {
                    if (panel.vault.unlock(text)) { text = ""; panel.message = "" }
                    else panel.message = qsTr("That's not the master password.")
                }
            }
            Ui.Pill { Layout.fillWidth: true; text: qsTr("Unlock"); onClicked: unlockPassword.accepted() }
            Item { Layout.fillHeight: true }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.dim
                font.pixelSize: Theme.px(11)
                text: qsTr("Forgot the master password? You can delete the vault and start again (all saved passwords are lost).")
            }
            Ui.Pill { text: qsTr("Delete vault…"); onClicked: forgetPopup.open() }
        }

        // ---------- unlocked ----------
        Text {
            visible: panel.vault.state === "unlocked" && (panel.health.weak > 0 || panel.health.reused > 0)
            text: qsTr("%1 weak and %2 reused passwords (checked on this computer only)").arg(panel.health.weak).arg(panel.health.reused)
            color: Theme.accent
            font.pixelSize: Theme.px(12)
        }
        Ui.Field {
            id: search
            visible: panel.vault.state === "unlocked"
            Layout.fillWidth: true
            placeholderText: qsTr("Search passwords")
        }
        ListView {
            id: list
            visible: panel.vault.state === "unlocked"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: panel.rows
            ScrollBar.vertical: ScrollBar { width: 4 }
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool open: panel.revealedId === modelData.id || panel.editingId === modelData.id || expanded
                property bool expanded: false
                width: ListView.view.width
                height: content.implicitHeight + 16
                radius: 10
                color: rowHover.hovered || expanded ? Theme.hover : "transparent"
                HoverHandler { id: rowHover }
                MouseArea { anchors.fill: parent; onClicked: row.expanded = !row.expanded }
                ColumnLayout {
                    id: content
                    x: 10
                    y: 8
                    width: parent.width - 20
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Text { text: panel.host(modelData.origin); color: Theme.fg; font.pixelSize: Theme.px(13); elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: modelData.username || qsTr("(no username)"); color: Theme.dim; font.pixelSize: Theme.px(11); elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        Ui.Badge { visible: modelData.weak; text: qsTr("weak") }
                        Ui.Badge { visible: modelData.reused; text: qsTr("reused") }
                    }
                    // Details: shown when the row is clicked.
                    RowLayout {
                        visible: row.expanded && panel.editingId !== modelData.id
                        Layout.fillWidth: true
                        Text {
                            visible: panel.revealedId === modelData.id
                            Layout.fillWidth: true
                            text: panel.revealed
                            color: Theme.fg
                            font.family: "Consolas, Menlo, monospace"
                            font.pixelSize: Theme.px(13)
                            elide: Text.ElideRight
                        }
                        Ui.Dots { visible: panel.revealedId !== modelData.id; Layout.fillWidth: true; color: Theme.fg }
                        IconButton { iconName: panel.revealedId === modelData.id ? "eye-off" : "eye"; tip: qsTr("Show password"); onClicked: panel.show(modelData.id) }
                        IconButton { iconName: "copy"; tip: qsTr("Copy password (cleared after 30 s)"); onClicked: { panel.vault.copy(modelData.id, "password"); panel.message = qsTr("Password copied. It's cleared from the clipboard in 30 seconds.") } }
                        IconButton { iconName: "edit"; tip: qsTr("Edit"); onClicked: { panel.editingId = modelData.id; editUser.text = modelData.username; editPass.text = ""; editOrigin.text = modelData.origin } }
                        IconButton { iconName: "trash"; tip: qsTr("Delete"); onClicked: panel.vault.remove(modelData.id) }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("No saved passwords yet.\nf1int offers to save them when you log in,\nor import them from Google / Chrome below.")
                color: Theme.dim
                font.pixelSize: Theme.px(12)
            }
        }

        // Add or edit one login.
        ColumnLayout {
            visible: panel.vault.state === "unlocked" && panel.editingId !== ""
            Layout.fillWidth: true
            spacing: 8
            Ui.Field { id: editOrigin; Layout.fillWidth: true; placeholderText: qsTr("Website, e.g. example.com") }
            Ui.Field { id: editUser; Layout.fillWidth: true; placeholderText: qsTr("Username or email") }
            RowLayout {
                Layout.fillWidth: true
                Ui.Field { id: editPass; Layout.fillWidth: true; placeholderText: panel.editingId === "new" ? qsTr("Password") : qsTr("New password (empty = keep)") }
                IconButton { iconName: "dice"; tip: qsTr("Generate a strong password"); onClicked: editPass.text = panel.vault.generate(20) }
            }
            RowLayout {
                Item { Layout.fillWidth: true }
                Ui.Pill { text: qsTr("Cancel"); onClicked: panel.editingId = "" }
                Ui.Pill {
                    primary: true
                    text: qsTr("Save")
                    onClicked: {
                        if (panel.editingId === "new") panel.vault.save(Browser.urlFromInput(editOrigin.text), editUser.text, editPass.text)
                        else panel.vault.edit(panel.editingId, editOrigin.text, editUser.text, editPass.text)
                        panel.editingId = ""
                    }
                }
            }
        }

        Flow {
            visible: panel.vault.state === "unlocked" && panel.editingId === ""
            Layout.fillWidth: true
            spacing: 8
            Ui.Pill { text: qsTr("+ Add"); onClicked: { panel.editingId = "new"; editOrigin.text = ""; editUser.text = ""; editPass.text = "" } }
            Ui.Pill { text: qsTr("Import CSV…"); onClicked: importDialog.open() }
            Ui.Pill { text: qsTr("Export CSV…"); onClicked: exportWarning.open() }
            Ui.Pill { text: qsTr("Generate"); onClicked: { const p = panel.vault.generate(20); panel.message = p; } }
        }
        RowLayout {
            visible: panel.vault.state === "unlocked"
            Layout.fillWidth: true
            Text { text: qsTr("Unlock with %1").arg(panel.deviceName); color: Theme.fg; font.pixelSize: Theme.px(12); Layout.fillWidth: true }
            Ui.Toggle { checked: panel.vault.deviceUnlock; onToggled: panel.vault.setDeviceUnlock(checked) }
        }
        // Keeps the setup and unlock forms at the top (the saved-logins list fills the space when unlocked).
        Item { visible: panel.vault.state === "none"; Layout.fillHeight: true }
    }

    // ---------- dialogs ----------
    FileDialog {
        id: importDialog
        title: qsTr("Import passwords (CSV from Google Password Manager or Chrome)")
        nameFilters: [qsTr("CSV files (*.csv)")]
        onAccepted: {
            const n = panel.vault.importCsv(selectedFile)
            panel.message = n < 0 ? qsTr("That file doesn't look like a password export.")
                                  : qsTr("Imported %1 passwords. Delete the CSV file now: it isn't encrypted.").arg(n)
        }
    }
    FileDialog {
        id: exportDialog
        fileMode: FileDialog.SaveFile
        defaultSuffix: "csv"
        nameFilters: [qsTr("CSV files (*.csv)")]
        onAccepted: panel.message = panel.vault.exportCsv(selectedFile) ? qsTr("Exported. Keep that file safe and delete it when you're done.")
                                                                       : qsTr("Couldn't write the file.")
    }

    component Dialog: Popup {
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 340
        padding: 20
        background: Rectangle { color: Theme.surface; radius: 16; border.width: 1; border.color: Theme.line }
    }
    Dialog {
        id: exportWarning
        contentItem: ColumnLayout {
            spacing: 14
            Ui.Heading { text: qsTr("Export passwords"); font.pixelSize: Theme.px(20) }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.fg
                font.pixelSize: Theme.px(13)
                text: qsTr("The file will contain all your passwords in plain text. Anyone who can open it can read them. Only export to a place you trust, and delete the file after use.")
            }
            RowLayout {
                Item { Layout.fillWidth: true }
                Ui.Pill { text: qsTr("Cancel"); onClicked: exportWarning.close() }
                Ui.Pill { primary: true; text: qsTr("Export anyway"); onClicked: { exportWarning.close(); exportDialog.open() } }
            }
        }
    }
    Dialog {
        id: verifyPopup
        onOpened: verifyField.forceActiveFocus()
        contentItem: ColumnLayout {
            spacing: 12
            Text { text: qsTr("Confirm it's you"); color: Theme.fg; font.pixelSize: Theme.px(15) }
            Ui.Field {
                id: verifyField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: qsTr("Master password")
                onAccepted: {
                    if (panel.vault.verify(text)) {
                        panel.revealedId = panel.pendingRevealId; panel.revealed = panel.vault.reveal(panel.pendingRevealId)
                        verifyPopup.close()
                    } else panel.message = qsTr("That's not the master password.")
                    text = ""
                }
            }
        }
    }
    Dialog {
        id: forgetPopup
        contentItem: ColumnLayout {
            spacing: 14
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.fg
                font.pixelSize: Theme.px(13)
                text: qsTr("Delete the password vault? All saved passwords in f1int are lost for good. This can't be undone.")
            }
            RowLayout {
                Item { Layout.fillWidth: true }
                Ui.Pill { text: qsTr("Cancel"); onClicked: forgetPopup.close() }
                Ui.Pill { primary: true; text: qsTr("Delete vault"); onClicked: { panel.vault.forgetVault(); forgetPopup.close() } }
            }
        }
    }
}
