import QtCore
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
    property bool importing: false      // showing the importer instead of the list
    readonly property string view: importing ? "import" : vault.state   // what the panel shows

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

    property bool embedded: false       // inside Settings (no side-panel edge)
    color: Theme.surface
    Rectangle { visible: !panel.embedded; width: 1; height: parent.height; color: Theme.line }
    // Drop an exported passwords file anywhere on the panel to import it.
    DropArea {
        anchors.fill: parent
        onEntered: (drag) => drag.accepted = drag.hasUrls
        onDropped: (drop) => { if (drop.hasUrls) { drop.accept(Qt.CopyAction); panel.importing = true; importer.take(drop.urls[0]) } }
    }

    Connections {
        target: Browser
        function onDeviceAuthFinished(purpose, ok, error) {
            if (purpose === "verify" && ok && panel.pendingRevealId !== "") {
                panel.revealedId = panel.pendingRevealId; panel.revealed = panel.vault.reveal(panel.pendingRevealId)
            }
            panel.pendingRevealId = ""
            panel.message = ok || panel.importing ? "" : error   // the importer shows its own
        }
    }
    Timer { running: panel.revealedId !== ""; interval: 30000; onTriggered: { panel.revealedId = ""; panel.revealed = "" } }   // hide again

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            IconButton { visible: panel.importing; iconName: "back"; tip: qsTr("Back to passwords"); onClicked: panel.importing = false }
            Ui.Heading { text: panel.importing ? qsTr("Import passwords") : qsTr("Passwords") }
            Text {
                visible: panel.view === "unlocked"
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
            visible: panel.view === "none"
            Layout.fillWidth: true
            Layout.maximumWidth: 420              // a form, not a banner, on a wide page
            Layout.alignment: Qt.AlignHCenter
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
                font.pixelSize: Theme.px(12)
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
            Ui.Pill { text: qsTr("Import from another browser…"); onClicked: { panel.message = ""; panel.importing = true } }
        }

        // ---------- locked ----------
        ColumnLayout {
            visible: panel.view === "locked"
            Layout.fillWidth: true
            Layout.maximumWidth: 380
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 40
            spacing: 12
            Icon { glyph: "lock"; sourceSize: Qt.size(40, 40); Layout.alignment: Qt.AlignHCenter; color: Theme.dim }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Your passwords are locked")
                color: Theme.fg
                font.pixelSize: Theme.px(16)
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("They're encrypted on this computer. Unlock to see, edit or fill them.")
                color: Theme.dim
                font.pixelSize: Theme.px(12)
            }
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
            Ui.Pill { Layout.fillWidth: true; text: qsTr("Import passwords…"); onClicked: { panel.message = ""; panel.importing = true } }
            Item { Layout.fillHeight: true }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.dim
                font.pixelSize: Theme.px(12)
                text: qsTr("Forgot the master password? You can delete the vault and start again (all saved passwords are lost).")
            }
            Ui.Pill { text: qsTr("Delete vault…"); onClicked: forgetPopup.open() }
        }

        // ---------- unlocked ----------
        Text {
            visible: panel.view === "unlocked" && (panel.health.weak > 0 || panel.health.reused > 0)
            text: qsTr("%1 weak and %2 reused passwords (checked on this computer only)").arg(panel.health.weak).arg(panel.health.reused)
            color: Theme.accent
            font.pixelSize: Theme.px(12)
        }
        Ui.Field {
            id: search
            visible: panel.view === "unlocked"
            Layout.fillWidth: true
            placeholderText: qsTr("Search passwords")
        }
        ListView {
            id: list
            visible: panel.view === "unlocked"
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
                            Text { text: modelData.username || qsTr("(no username)"); color: Theme.dim; font.pixelSize: Theme.px(12); elide: Text.ElideRight; Layout.fillWidth: true }
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
                text: qsTr("No saved passwords yet.\nf1int offers to save them when you log in,\nor import them from another browser below.")
                color: Theme.dim
                font.pixelSize: Theme.px(12)
            }
        }

        // Add or edit one login.
        ColumnLayout {
            visible: panel.view === "unlocked" && panel.editingId !== ""
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
            visible: panel.view === "unlocked" && panel.editingId === ""
            Layout.fillWidth: true
            spacing: 8
            Ui.Pill { text: qsTr("+ Add"); onClicked: { panel.editingId = "new"; editOrigin.text = ""; editUser.text = ""; editPass.text = "" } }
            Ui.Pill { text: qsTr("Import…"); onClicked: { panel.message = ""; panel.importing = true } }
            Ui.Pill { text: qsTr("Export CSV…"); onClicked: exportWarning.open() }
            Ui.Pill { text: qsTr("Generate"); onClicked: { const p = panel.vault.generate(20); panel.message = p; } }
        }
        RowLayout {
            visible: panel.view === "unlocked"
            Layout.fillWidth: true
            Text { text: qsTr("Unlock with %1").arg(panel.deviceName); color: Theme.fg; font.pixelSize: Theme.px(12); Layout.fillWidth: true }
            Ui.Toggle { checked: panel.vault.deviceUnlock; onToggled: panel.vault.setDeviceUnlock(checked) }
        }

        // ---------- import ----------
        Importer { id: importer; visible: panel.importing; Layout.fillWidth: true }
        Ui.Pill { visible: panel.importing && panel.vault.state === "unlocked"; text: qsTr("Done"); onClicked: panel.importing = false }
        // Keeps the forms at the top (the saved-logins list fills the space when unlocked).
        Item { visible: panel.view === "none" || panel.importing; Layout.fillHeight: true }
    }

    // ---------- importing from another browser or password manager ----------
    // How to export them, a drop zone and file picker, the master password when the vault needs
    // one (create or unlock it right here), then what happened and an offer to delete the export.
    // The welcome intro uses it too, as PasswordsPanel.Importer.
    component Importer: ColumnLayout {
        id: imp
        readonly property var vault: Browser.passwords
        readonly property string deviceName: Qt.platform.os === "osx" ? "Touch ID" : "Windows Hello"
        property url file                 // the exported file, dropped or chosen
        property bool waiting: false      // a file is chosen and not imported yet
        property bool imported: false     // done: offer to delete the file
        property string result: ""
        property bool problem: false
        property int source: 0            // whose export steps are shown
        property bool copied: false
        readonly property var sources: [
            { label: "Chrome", address: "chrome://password-manager/settings",
              steps: qsTr("Open Chrome, paste this into its address bar, then next to Export passwords click Download file.") },
            { label: "Edge", address: "edge://wallet/passwords",
              steps: qsTr("Open Edge, paste this into its address bar, then click ⋯ (More actions) › Export passwords.") },
            { label: "Firefox", address: "about:logins",
              steps: qsTr("Open Firefox, paste this into its address bar, then click ⋯ (top right) › Export passwords.") },
            { label: qsTr("Other"), address: "",
              steps: qsTr("Safari, Bitwarden, 1Password, LastPass and most password managers can export a CSV file too.") }]

        function fileName() { const s = decodeURIComponent(file.toString()); return s.substring(s.lastIndexOf("/") + 1) }
        function say(text, bad) { result = text; problem = bad }
        function copy(text) { clip.text = text; clip.selectAll(); clip.copy(); copied = true; copiedTimer.restart() }
        // A file was dropped or picked: import it now, or as soon as the vault is open.
        function take(url) { file = url; waiting = true; imported = false; run() }
        function run() {
            if (vault.state === "none") {
                if (master.text.length < 8) {
                    say(qsTr("Now choose a master password for f1int (8 or more characters). It keeps these passwords encrypted."), false)
                    master.forceActiveFocus(); return
                }
                if (master.text !== repeat.text) { say(qsTr("The two passwords don't match."), true); repeat.forceActiveFocus(); return }
                if (!vault.setUp(master.text, true)) { say(qsTr("Couldn't create the password vault."), true); return }
            } else if (vault.state === "locked") {
                if (master.text === "") {
                    say(vault.deviceUnlock ? qsTr("Now unlock your passwords with %1 or your master password.").arg(deviceName)
                                           : qsTr("Now type your master password to unlock your passwords."), false)
                    master.forceActiveFocus(); return
                }
                if (!vault.unlock(master.text)) { say(qsTr("That's not the master password."), true); master.selectAll(); master.forceActiveFocus(); return }
            }
            master.text = ""; repeat.text = ""
            const r = vault.importCsv(file)
            waiting = false
            if (r.error) { say(r.error, true); return }
            let text = r.imported === 0 ? qsTr("No new passwords.") : r.imported === 1 ? qsTr("Imported 1 password.")
                                                                                         : qsTr("Imported %1 passwords.").arg(r.imported)
            if (r.skipped > 0) text += " " + qsTr("%1 skipped (no password or website).").arg(r.skipped)
            if (r.duplicates > 0) text += " " + qsTr("%1 already saved.").arg(r.duplicates)
            say(text, false)
            imported = true
        }
        function deleteFile() {
            const cloud = file.toString().indexOf("/OneDrive") >= 0
            if (vault.deleteImportedFile()) {
                say(qsTr("Deleted %1.").arg(fileName()) + (cloud ? " " + qsTr("It was in OneDrive, so also empty the recycle bin on onedrive.com.") : ""), false)
                file = ""
            } else say(qsTr("Couldn't delete %1. Please delete it yourself: it holds your passwords in plain text.").arg(fileName()), true)
            imported = false
        }

        spacing: 8
        Connections {   // Windows Hello / Touch ID said yes: carry on with the waiting file
            target: Browser
            function onDeviceAuthFinished(purpose, ok, error) {
                if (purpose !== "unlock" || !imp.waiting) return
                if (ok) imp.run(); else imp.say(error, true)
            }
        }
        TextEdit { id: clip; visible: false }   // for the clipboard
        Timer { id: copiedTimer; interval: 1500; onTriggered: imp.copied = false }

        // 1. Get the file out of the other browser (f1int can't open its pages, so: copy the address).
        // One step at a time: hidden while a file is on its way in or once it's imported.
        ColumnLayout {
            visible: !imp.waiting && !imp.imported
            Layout.fillWidth: true
            spacing: 8
            Text { text: qsTr("1. Export them from your other browser"); color: Theme.fg; font.pixelSize: Theme.px(13); font.weight: Font.DemiBold }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Ui.Segmented {
                    options: imp.sources.map((s, i) => ({ label: s.label, value: i }))
                    value: imp.source
                    onPicked: (v) => { imp.source = v; imp.copied = false }
                }
                Rectangle {
                    visible: imp.sources[imp.source].address !== ""
                    width: address.implicitWidth + 50
                    height: 30
                    radius: Theme.radius
                    color: Theme.field
                    Text {
                        id: address
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: imp.sources[imp.source].address
                        color: Theme.fg
                        font.family: "Consolas"
                        font.pixelSize: Theme.px(12)
                    }
                    IconButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: imp.copied ? "check" : "copy"
                        tip: qsTr("Copy the address")
                        onClicked: imp.copy(address.text)
                    }
                }
            }
            Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: imp.sources[imp.source].steps; color: Theme.dim; font.pixelSize: Theme.px(12) }
        }

        // 2. Bring the file here.
        Text { text: qsTr("2. Drop the file here or choose it"); color: Theme.fg; font.pixelSize: Theme.px(13); font.weight: Font.DemiBold }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: Theme.cardRadius
            color: dropZone.containsDrag ? Theme.accentSoft : Theme.field
            border.width: 1
            border.color: dropZone.containsDrag ? Theme.accent : Theme.line
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10
                Icon { glyph: imp.file.toString() !== "" ? "check" : "download"; color: Theme.dim }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: imp.file.toString() !== "" ? imp.fileName() : qsTr("Drop the exported .csv file here")
                    color: imp.file.toString() !== "" ? Theme.fg : Theme.dim
                    font.pixelSize: Theme.px(13)
                }
                Ui.Pill { text: qsTr("Choose file…"); onClicked: picker.open() }
            }
            DropArea {
                id: dropZone
                anchors.fill: parent
                onEntered: (drag) => drag.accepted = drag.hasUrls
                onDropped: (drop) => { if (drop.hasUrls) { drop.accept(Qt.CopyAction); imp.take(drop.urls[0]) } }
            }
        }

        // 3. The vault: created or unlocked right here, once a file is waiting for it.
        Text {
            visible: imp.waiting && imp.vault.state !== "unlocked"
            text: imp.vault.state === "none" ? qsTr("3. Choose a master password for f1int") : qsTr("3. Unlock your f1int passwords")
            color: Theme.fg
            font.pixelSize: Theme.px(13)
            font.weight: Font.DemiBold
        }
        GridLayout {
            readonly property bool wide: imp.width > 500
            visible: imp.waiting && imp.vault.state !== "unlocked"
            Layout.fillWidth: true
            columns: wide ? 3 : 1
            columnSpacing: 8
            rowSpacing: 8
            Ui.Pill {
                visible: imp.vault.state === "locked" && imp.vault.deviceUnlock
                Layout.fillWidth: true
                text: qsTr("Unlock with %1").arg(imp.deviceName)
                onClicked: Browser.askDevice(Window.window, "unlock")
            }
            Ui.Field {
                id: master
                Layout.fillWidth: true
                Layout.preferredWidth: 150   // same width as "Repeat it"
                echoMode: TextInput.Password
                placeholderText: imp.vault.state === "none" ? qsTr("Master password (8+ characters)") : qsTr("Master password")
                onAccepted: imp.vault.state === "none" ? repeat.forceActiveFocus() : imp.run()
            }
            Ui.Field {
                id: repeat
                visible: imp.vault.state === "none"
                Layout.fillWidth: true
                Layout.preferredWidth: 150
                echoMode: TextInput.Password
                placeholderText: qsTr("Repeat it")
                onAccepted: imp.run()
            }
            Ui.Pill {
                primary: true
                Layout.fillWidth: !parent.wide
                text: imp.vault.state === "none" ? qsTr("Create vault and import") : qsTr("Unlock and import")
                onClicked: imp.run()
            }
        }

        // What happened.
        Text {
            visible: imp.result !== ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: imp.result
            color: imp.problem ? Theme.accent : Theme.fg
            font.pixelSize: Theme.px(13)
        }
        Flow {
            visible: imp.imported
            Layout.fillWidth: true
            spacing: 10
            Text { height: 30; verticalAlignment: Text.AlignVCenter; text: qsTr("The exported file holds your passwords in plain text."); color: Theme.dim; font.pixelSize: Theme.px(12) }
            Ui.Pill { text: qsTr("Delete the exported file"); onClicked: imp.deleteFile() }
        }

        FileDialog {
            id: picker
            title: qsTr("Choose the exported passwords file")
            currentFolder: StandardPaths.standardLocations(StandardPaths.DownloadLocation)[0]
            nameFilters: [qsTr("Password exports (*.csv)"), qsTr("All files (*)")]
            onAccepted: imp.take(selectedFile)
        }
    }

    // ---------- dialogs ----------
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
