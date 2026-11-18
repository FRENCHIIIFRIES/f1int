import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import f1int

// Settings > Account and sync. f1int works fully without an account; an account only adds
// sync between computers. Everything synced is encrypted on this computer first.
ColumnLayout {
    id: page
    readonly property var acc: Browser.account
    property string mode: "signIn"            // signIn | create | forgot (while signed out)
    spacing: 22

    function ago(when) {
        if (!when || isNaN(when.getTime())) return qsTr("never")
        const s = Math.round((Date.now() - when.getTime()) / 1000)
        return s < 60 ? qsTr("just now") : s < 3600 ? qsTr("%1 min ago").arg(Math.round(s / 60))
             : s < 86400 ? qsTr("%1 h ago").arg(Math.round(s / 3600)) : when.toLocaleDateString()
    }

    // ---- the notice line (errors and confirmations) ----
    Rectangle {
        visible: page.acc.message !== ""
        Layout.fillWidth: true
        implicitHeight: noticeText.implicitHeight + 22
        radius: Theme.radius
        color: Theme.accentSoft
        Text {
            id: noticeText
            x: 14; y: 11
            width: parent.width - 50
            wrapMode: Text.WordWrap
            text: page.acc.message
            color: Theme.fg
            font.pixelSize: Theme.px(13)
        }
        IconButton {
            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
            iconName: "close"; iconSize: 12; iconColor: Theme.dim; tip: qsTr("Dismiss")
            onClicked: page.acc.clearMessage()
        }
    }

    // ================= signed out =================
    Ui.Section {
        visible: page.acc.state === "signedOut"
        title: page.mode === "create" ? qsTr("Create an f1int account") : page.mode === "forgot" ? qsTr("Reset your password") : qsTr("Sign in")
        Item {
            Layout.fillWidth: true
            implicitHeight: signForm.implicitHeight + 36
            ColumnLayout {
                id: signForm
                x: 18; y: 18
                width: Math.min(420, parent.width - 36)
                spacing: 10
                Ui.Segmented {
                    visible: page.mode !== "forgot"
                    options: [{ label: qsTr("Sign in"), value: "signIn" }, { label: qsTr("Create account"), value: "create" }]
                    value: page.mode
                    onPicked: (v) => { page.mode = v; page.acc.clearMessage() }
                }
                Ui.Field {
                    id: emailField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Email")
                    text: page.acc.email
                    inputMethodHints: Qt.ImhEmailCharactersOnly
                    Accessible.name: qsTr("Email")
                }
                Ui.Field {
                    id: passwordField
                    visible: page.mode !== "forgot"
                    Layout.fillWidth: true
                    placeholderText: page.mode === "create" ? qsTr("Password (8 or more characters)") : qsTr("Password")
                    echoMode: TextInput.Password
                    Accessible.name: qsTr("Password")
                    onAccepted: submit.clicked()
                }
                Ui.Field {
                    id: repeatField
                    visible: page.mode === "create"
                    Layout.fillWidth: true
                    placeholderText: qsTr("Password again")
                    echoMode: TextInput.Password
                    Accessible.name: qsTr("Repeat password")
                    onAccepted: submit.clicked()
                }
                RowLayout {
                    spacing: 10
                    Ui.Pill {
                        id: submit
                        primary: true
                        enabled: !page.acc.busy
                        text: page.mode === "create" ? qsTr("Create account") : page.mode === "forgot" ? qsTr("Send reset link") : qsTr("Sign in")
                        onClicked: {
                            if (page.mode === "forgot") return page.acc.requestReset(emailField.text)
                            if (page.mode === "create") {
                                if (passwordField.text !== repeatField.text) return   // the mismatch is shown under the fields
                                page.acc.signUp(emailField.text, passwordField.text)
                            } else page.acc.signIn(emailField.text, passwordField.text)
                            passwordField.text = ""; repeatField.text = ""
                        }
                    }
                    DotLoader { visible: page.acc.busy }
                    Text {
                        visible: page.mode !== "create"
                        text: page.mode === "forgot" ? qsTr("Back to sign in") : qsTr("Forgot your password?")
                        color: Theme.accent
                        font.pixelSize: Theme.px(12)
                        font.underline: forgotHover.hovered
                        HoverHandler { id: forgotHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: { page.mode = page.mode === "forgot" ? "signIn" : "forgot"; page.acc.clearMessage() } }
                    }
                }
                Text {
                    visible: page.mode === "create" && repeatField.text !== "" && passwordField.text !== repeatField.text
                    text: qsTr("The two passwords don't match.")
                    color: Theme.accent2
                    font.pixelSize: Theme.px(12)
                }
                Text {
                    visible: page.mode === "forgot"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("Your synced data is locked with your password, so after a reset it can't be opened any more: it's uploaded again from this computer. Bookmarks and settings on this computer are never lost.")
                    color: Theme.dim
                    font.pixelSize: Theme.px(12)
                }
            }
        }
    }
    Ui.Section {
        visible: page.acc.state === "signedOut"
        title: qsTr("What an account does")
        Ui.SettingRow { label: qsTr("Optional"); hint: qsTr("f1int works fully without one. An account only adds sync between your computers.") }
        Ui.SettingRow { label: qsTr("Encrypted before it leaves this computer"); hint: qsTr("Bookmarks, settings, themes and the new tab page are encrypted here with a key only your password can open (AES-256). The server stores scrambled data it can't read, and never sees your password.") }
        Ui.SettingRow { label: qsTr("You choose what syncs"); hint: qsTr("History only if you turn it on. Saved passwords never sync.") }
        Ui.SettingRow { label: qsTr("Where it's kept"); hint: qsTr("Supabase (Mumbai region). Delete your account at any time and everything on the server goes with it."); last: true }
    }

    // ================= waiting for an email link =================
    Ui.Section {
        visible: page.acc.state === "confirmEmail" || page.acc.state === "resetSent"
        title: qsTr("Check your email")
        Item {
            Layout.fillWidth: true
            implicitHeight: waitCol.implicitHeight + 36
            ColumnLayout {
                id: waitCol
                x: 18; y: 18
                width: parent.width - 36
                spacing: 10
                Row {
                    spacing: 10
                    Icon { glyph: "sync"; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: qsTr("Open the link we sent to %1 on this computer.").arg(page.acc.email); color: Theme.fg; font.pixelSize: Theme.px(14); anchors.verticalCenter: parent.verticalCenter }
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("f1int notices when you open it. If the link opens in a browser on another computer, copy it from the email and paste it here instead.")
                    color: Theme.dim
                    font.pixelSize: Theme.px(12)
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Ui.Field { id: linkField; Layout.fillWidth: true; placeholderText: qsTr("Paste the link from the email"); onAccepted: useLink.clicked() }
                    Ui.Pill { id: useLink; text: qsTr("Use link"); enabled: linkField.text.trim() !== ""; onClicked: { page.acc.useLink(linkField.text); linkField.text = "" } }
                }
                Row {
                    spacing: 8
                    Ui.Pill { visible: page.acc.state === "confirmEmail"; text: qsTr("Send it again"); onClicked: page.acc.resendConfirmation() }
                    Ui.Pill { text: qsTr("Start over"); onClicked: { page.acc.signOut(); page.mode = "signIn" } }
                }
            }
        }
    }

    // ================= choose a new password / unlock again =================
    Ui.Section {
        visible: page.acc.state === "newPassword" || page.acc.state === "needsPassword"
        title: page.acc.state === "newPassword" ? qsTr("Choose a new password") : qsTr("Unlock sync")
        Item {
            Layout.fillWidth: true
            implicitHeight: pwCol.implicitHeight + 36
            ColumnLayout {
                id: pwCol
                x: 18; y: 18
                width: Math.min(420, parent.width - 36)
                spacing: 10
                Text { text: page.acc.email; color: Theme.dim; font.pixelSize: Theme.px(12) }
                Ui.Field { id: newPw; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: page.acc.state === "newPassword" ? qsTr("New password (8 or more characters)") : qsTr("Password"); Accessible.name: qsTr("Password") }
                Ui.Field { id: newPw2; visible: page.acc.state === "newPassword"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: qsTr("New password again"); Accessible.name: qsTr("Repeat password") }
                Text { visible: newPw2.visible && newPw2.text !== "" && newPw.text !== newPw2.text; text: qsTr("The two passwords don't match."); color: Theme.accent2; font.pixelSize: Theme.px(12) }
                Row {
                    spacing: 8
                    Ui.Pill {
                        primary: true
                        enabled: !page.acc.busy && newPw.text.length > 0 && (!newPw2.visible || newPw.text === newPw2.text)
                        text: page.acc.state === "newPassword" ? qsTr("Save password") : qsTr("Unlock")
                        onClicked: { page.acc.state === "newPassword" ? page.acc.setNewPassword(newPw.text) : page.acc.signIn(page.acc.email, newPw.text); newPw.text = ""; newPw2.text = "" }
                    }
                    Ui.Pill { text: qsTr("Sign out"); onClicked: page.acc.signOut() }
                }
            }
        }
    }

    // ================= signed in =================
    Ui.Section {
        visible: page.acc.state === "signedIn"
        title: qsTr("Your account")
        Ui.SettingRow {
            label: page.acc.username !== "" ? page.acc.username : qsTr("No username yet")
            hint: page.acc.email
            Row {
                spacing: 8
                Ui.Avatar { width: 36; height: 36; name: page.acc.username || page.acc.email; picture: page.acc.avatar; anchors.verticalCenter: parent.verticalCenter }
                Ui.Pill { text: qsTr("Picture…"); onClicked: avatarDialog.open(); anchors.verticalCenter: parent.verticalCenter }
                Ui.Pill { visible: page.acc.avatar !== ""; text: qsTr("Remove"); onClicked: page.acc.clearAvatar(); anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Ui.SettingRow {
            label: qsTr("Username")
            hint: qsTr("3 to 30 letters, numbers, dots, dashes or underscores")
            last: true
            Row {
                spacing: 8
                Ui.Field { id: nameField; width: 180; text: page.acc.username; placeholderText: qsTr("username"); onAccepted: page.acc.setUsername(text) }
                Ui.Pill { text: qsTr("Save"); enabled: nameField.text !== page.acc.username; onClicked: page.acc.setUsername(nameField.text) }
            }
        }
    }
    FileDialog {
        id: avatarDialog
        nameFilters: [qsTr("Pictures (*.png *.jpg *.jpeg *.webp *.bmp *.gif)")]
        onAccepted: page.acc.setAvatar(selectedFile)
    }

    Ui.Section {
        visible: page.acc.state === "signedIn"
        title: qsTr("Sync")
        Ui.SettingRow {
            label: qsTr("Sync this computer")
            hint: !page.acc.syncOn ? qsTr("Off: nothing is sent")
                  : page.acc.syncStatus === "syncing" ? qsTr("Syncing…")
                  : page.acc.syncStatus === "error" ? qsTr("Couldn't sync: %1").arg(page.acc.lastSyncNote)
                  : qsTr("Last synced %1").arg(page.ago(page.acc.lastSync)) + (page.acc.lastSyncNote ? ". " + page.acc.lastSyncNote : "")
            Row {
                spacing: 8
                Ui.Pill { visible: page.acc.syncOn; text: qsTr("Sync now"); enabled: page.acc.syncStatus !== "syncing"; onClicked: page.acc.syncNow(); anchors.verticalCenter: parent.verticalCenter }
                Ui.Toggle { checked: page.acc.syncOn; onToggled: page.acc.setSyncOn(checked); anchors.verticalCenter: parent.verticalCenter; Accessible.name: qsTr("Sync") }
            }
        }
        Repeater {
            model: [{ kind: "bookmarks", label: qsTr("Bookmarks") },
                    { kind: "settings", label: qsTr("Settings and look"), hint: qsTr("Including shortcuts, tab and sidebar choices") },
                    { kind: "themes", label: qsTr("Saved themes") },
                    { kind: "newtab", label: qsTr("New tab page"), hint: qsTr("Widgets, shortcuts, notes and to-dos") },
                    { kind: "history", label: qsTr("History"), hint: qsTr("Your last 5,000 pages, encrypted. Off unless you turn it on.") }]
            Ui.SettingRow {
                id: kindRow
                required property var modelData
                visible: page.acc.syncOn && (Theme.settingsFilter === "" || (label + " " + hint).toLowerCase().indexOf(Theme.settingsFilter) >= 0)
                label: modelData.label
                hint: modelData.hint || ""
                Ui.Toggle { checked: page.acc.syncKinds[kindRow.modelData.kind] === true; onToggled: page.acc.setSyncKind(kindRow.modelData.kind, checked); Accessible.name: kindRow.modelData.label }
            }
        }
        Ui.SettingRow {
            label: qsTr("Not synced")
            hint: qsTr("Saved passwords (they stay encrypted on this computer), open tabs and downloads.")
            last: true
        }
    }

    Ui.Section {
        visible: page.acc.state === "signedIn"
        title: qsTr("Your computers")
        Repeater {
            model: page.acc.devices
            Ui.SettingRow {
                id: deviceRow
                required property var modelData
                required property int index
                label: modelData.name + (modelData.current ? " " + qsTr("(this computer)") : "")
                hint: (modelData.platform || "") + " · " + qsTr("last seen %1").arg(page.ago(new Date(modelData.last_seen)))
                last: index === page.acc.devices.length - 1
                Row {
                    spacing: 6
                    Ui.Pill { visible: deviceRow.modelData.current; text: qsTr("Rename…"); onClicked: { renameField.text = deviceRow.modelData.name; renameDevice.deviceId = deviceRow.modelData.id; renameDevice.open() } }
                    Ui.Pill {
                        text: deviceRow.modelData.current ? qsTr("Sign out here") : qsTr("Remove")
                        onClicked: page.acc.removeDevice(deviceRow.modelData.id)
                    }
                }
            }
        }
    }
    Popup {
        id: renameDevice
        property string deviceId: ""
        anchors.centerIn: Overlay.overlay
        modal: true
        padding: 18
        background: Rectangle { color: Theme.surface; radius: Theme.cardRadius; border.width: 1; border.color: Theme.line }
        contentItem: Column {
            spacing: 12
            Text { text: qsTr("Name this computer"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold }
            Ui.Field { id: renameField; width: 260; maximumLength: 80 }
            Row {
                spacing: 8
                Ui.Pill { primary: true; text: qsTr("Save"); onClicked: { page.acc.renameDevice(renameDevice.deviceId, renameField.text); renameDevice.close() } }
                Ui.Pill { text: qsTr("Cancel"); onClicked: renameDevice.close() }
            }
        }
    }

    Ui.Section {
        visible: page.acc.state === "signedIn"
        title: qsTr("Security")
        Ui.SettingRow {
            label: qsTr("Change password")
            hint: qsTr("Your synced data stays, locked with the new one")
            Row {
                spacing: 6
                Ui.Field { id: curPw; width: 130; echoMode: TextInput.Password; placeholderText: qsTr("Current"); Accessible.name: qsTr("Current password") }
                Ui.Field { id: nextPw; width: 130; echoMode: TextInput.Password; placeholderText: qsTr("New (8+)"); Accessible.name: qsTr("New password") }
                Ui.Pill { text: qsTr("Change"); enabled: curPw.text !== "" && nextPw.text.length >= 8 && !page.acc.busy
                          onClicked: { page.acc.changePassword(curPw.text, nextPw.text); curPw.text = ""; nextPw.text = "" } }
            }
        }
        Ui.SettingRow {
            label: qsTr("Sign out")
            hint: qsTr("Sync stops on this computer. Your bookmarks and settings stay here.")
            Ui.Pill { text: qsTr("Sign out"); onClicked: page.acc.signOut() }
        }
        Ui.SettingRow {
            label: qsTr("Delete account")
            hint: qsTr("Deletes your account and everything synced from the server, for good. What's on this computer stays.")
            last: true
            Ui.Pill { text: qsTr("Delete…"); onClicked: deleteAccount.open() }
        }
    }
    Popup {
        id: deleteAccount
        anchors.centerIn: Overlay.overlay
        modal: true
        padding: 20
        width: 380
        onOpened: confirmPw.forceActiveFocus()
        background: Rectangle { color: Theme.surface; radius: Theme.cardRadius; border.width: 1; border.color: Theme.line }
        contentItem: Column {
            spacing: 12
            Text { text: qsTr("Delete your f1int account?"); color: Theme.fg; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: qsTr("Your account, your computers list and everything synced are deleted from the server. This can't be undone. Enter your password to confirm.")
                color: Theme.dim
                font.pixelSize: Theme.px(13)
            }
            Ui.Field { id: confirmPw; width: parent.width; echoMode: TextInput.Password; placeholderText: qsTr("Password"); Accessible.name: qsTr("Password") }
            Row {
                spacing: 8
                Ui.Pill { primary: true; text: qsTr("Delete account"); enabled: confirmPw.text !== ""
                          onClicked: { page.acc.deleteAccount(confirmPw.text); confirmPw.text = ""; deleteAccount.close() } }
                Ui.Pill { text: qsTr("Cancel"); onClicked: { confirmPw.text = ""; deleteAccount.close() } }
            }
        }
    }
}
