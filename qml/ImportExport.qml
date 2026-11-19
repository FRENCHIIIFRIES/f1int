import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import f1int

// Settings > Import and backup. The import wizard: find browsers (only when you ask) →
// pick a profile → pick what to bring → see what would be added → import → summary.
// Then exporting bookmarks and history, and backing up / restoring your whole setup.
ColumnLayout {
    id: io
    signal openPasswords()
    spacing: 22

    // ---------- import wizard ----------
    property int step: 0             // 0 start, 1 profiles, 2 what to bring, 3 preview, 4 importing, 5 done
    property var profiles: []
    property var picked: null       // { browser, name, path, kind }
    property var what: ({ bookmarks: true, history: true, search: true })
    property var preview: null      // dry-run result
    property var result: null
    function number(n) { return Number(n || 0).toLocaleString(Qt.locale(), "f", 0) }

    Ui.Section {
        title: qsTr("Import from another browser")
        Item {
            Layout.fillWidth: true
            implicitHeight: wizard.implicitHeight + 36
            ColumnLayout {
                id: wizard
                x: 18; y: 18
                width: parent.width - 36
                spacing: 14

                // Where we are: five small steps.
                Row {
                    spacing: 6
                    Repeater {
                        model: [qsTr("Browser"), qsTr("What"), qsTr("Check"), qsTr("Import")]
                        Row {
                            id: stepItem
                            required property string modelData
                            required property int index
                            readonly property bool reached: io.step >= index + 1
                            spacing: 6
                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: stepItem.reached ? Theme.accent : "transparent"
                                border.width: 1; border.color: stepItem.reached ? Theme.accent : Theme.line
                                Text { anchors.centerIn: parent; text: stepItem.index + 1; color: stepItem.reached ? Theme.textOnAccent : Theme.dim; font.pixelSize: Theme.px(12); font.family: Theme.numberFont; font.weight: Font.Bold }
                            }
                            Text { text: stepItem.modelData; color: stepItem.reached ? Theme.fg : Theme.dim; font.pixelSize: Theme.px(12); anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { visible: stepItem.index < 3; width: 18; height: 1; color: Theme.line; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                // 0: start
                ColumnLayout {
                    visible: io.step === 0
                    spacing: 10
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr("f1int can copy bookmarks, history and the search engine from Chrome, Edge, Brave, Opera and Firefox on this computer. It only looks at them when you press the button, reads copies, and never changes the other browser.")
                        color: Theme.dim
                        font.pixelSize: Theme.px(13)
                    }
                    Row {
                        spacing: 8
                        Ui.Pill { primary: true; text: qsTr("Find browsers on this computer"); onClicked: { io.profiles = Browser.library.otherBrowserProfiles(); io.step = 1 } }
                        Ui.Pill { text: qsTr("Bookmarks from an HTML file…"); onClicked: htmlDialog.open() }
                    }
                }

                // 1: pick a profile
                ColumnLayout {
                    visible: io.step === 1
                    spacing: 8
                    Text {
                        visible: io.profiles.length === 0
                        text: qsTr("No other browsers found. You can still import an HTML bookmarks file.")
                        color: Theme.dim
                        font.pixelSize: Theme.px(13)
                    }
                    Repeater {
                        model: io.profiles
                        Rectangle {
                            id: profileCard
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            radius: Theme.radius
                            color: profileHover.hovered ? Theme.hover : Theme.field
                            HoverHandler { id: profileHover; cursorShape: Qt.PointingHandCursor }
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.browser + " " + modelData.name
                            Rectangle {   // a letter, not the browser's logo
                                id: letter
                                x: 12; anchors.verticalCenter: parent.verticalCenter
                                width: 28; height: 28; radius: 14
                                color: Theme.surface
                                Text { anchors.centerIn: parent; text: profileCard.modelData.browser.charAt(0); color: Theme.fg; font.weight: Font.DemiBold; font.pixelSize: Theme.px(13) }
                            }
                            Column {
                                anchors.left: letter.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                Text { text: profileCard.modelData.browser; color: Theme.fg; font.pixelSize: Theme.px(13); font.weight: Font.Medium }
                                Text { text: profileCard.modelData.name; color: Theme.dim; font.pixelSize: Theme.px(12) }
                            }
                            Icon { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; glyph: "forward"; color: Theme.dim; sourceSize: Qt.size(14, 14) }
                            MouseArea { anchors.fill: parent; onClicked: { io.picked = profileCard.modelData; io.step = 2 } }
                        }
                    }
                    Ui.Pill { text: qsTr("Back"); onClicked: io.step = 0 }
                }

                // 2: what to bring
                ColumnLayout {
                    visible: io.step === 2
                    spacing: 10
                    Text { text: io.picked ? qsTr("From %1 (%2)").arg(io.picked.browser).arg(io.picked.name) : ""; color: Theme.fg; font.pixelSize: Theme.px(14); font.weight: Font.Medium }
                    Repeater {
                        model: [{ key: "bookmarks", label: qsTr("Bookmarks") }, { key: "history", label: qsTr("History") },
                                { key: "search", label: qsTr("Default search engine"), chromiumOnly: true }]
                        RowLayout {
                            id: whatRow
                            required property var modelData
                            visible: !modelData.chromiumOnly || (io.picked && io.picked.kind === "chromium")
                            spacing: 12
                            Ui.Toggle {
                                checked: io.what[whatRow.modelData.key] === true
                                onToggled: { const w = Object.assign({}, io.what); w[whatRow.modelData.key] = checked; io.what = w }
                                Accessible.name: whatRow.modelData.label
                            }
                            Text { text: whatRow.modelData.label; color: Theme.fg; font.pixelSize: Theme.px(13) }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr("Passwords: browsers keep them locked, so they can't be read directly. Export them from the other browser as a CSV file and import it in Passwords: it walks you through it.")
                        color: Theme.dim
                        font.pixelSize: Theme.px(12)
                    }
                    Row {
                        spacing: 8
                        Ui.Pill { text: qsTr("Back"); onClicked: io.step = 1 }
                        Ui.Pill {
                            primary: true
                            text: qsTr("Check what's there")
                            enabled: io.what.bookmarks || io.what.history || io.what.search
                            onClicked: { io.preview = Browser.library.importProfile(io.picked.path, Object.assign({ dryRun: true }, io.what)); io.step = 3 }
                        }
                        Ui.Pill { text: qsTr("Import passwords…"); onClicked: io.openPasswords() }
                    }
                }

                // 3: preview, then confirm
                ColumnLayout {
                    visible: io.step === 3
                    spacing: 10
                    Text { text: qsTr("This will add:"); color: Theme.fg; font.pixelSize: Theme.px(14); font.weight: Font.Medium }
                    Grid {
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 6
                        Text { visible: io.what.bookmarks; text: io.preview ? io.number(io.preview.bookmarks) : ""; color: Theme.fg; font.family: Theme.numberFont; font.pixelSize: Theme.px(20); font.weight: Font.Bold }
                        Text { visible: io.what.bookmarks; text: qsTr("new bookmarks"); color: Theme.dim; font.pixelSize: Theme.px(13) }
                        Text { visible: io.what.history; text: io.preview ? io.number(io.preview.history) : ""; color: Theme.fg; font.family: Theme.numberFont; font.pixelSize: Theme.px(20); font.weight: Font.Bold }
                        Text { visible: io.what.history; text: qsTr("pages of history"); color: Theme.dim; font.pixelSize: Theme.px(13) }
                    }
                    Text {
                        visible: io.what.search && io.preview && io.preview.search !== ""
                        text: io.preview ? qsTr("Search engine: %1").arg(String(io.preview.search).replace(/^https?:\/\/(www\.)?/, "").split("/")[0]) : ""
                        color: Theme.fg
                        font.pixelSize: Theme.px(13)
                    }
                    Text { visible: io.preview && io.preview.error !== undefined; text: io.preview && io.preview.error ? io.preview.error : ""; color: Theme.accent2; font.pixelSize: Theme.px(12) }
                    Text { text: qsTr("Things you already have are skipped."); color: Theme.dim; font.pixelSize: Theme.px(12) }
                    Row {
                        spacing: 8
                        Ui.Pill { text: qsTr("Back"); onClicked: io.step = 2 }
                        Ui.Pill { primary: true; text: qsTr("Import"); onClicked: { io.step = 4; importTimer.start() } }
                    }
                }
                Timer {   // a moment for the "importing" state to show before the work starts
                    id: importTimer
                    interval: 80
                    onTriggered: {
                        io.result = Browser.library.importProfile(io.picked.path, io.what)
                        if (io.what.search && io.result.search) Browser.setSetting("search/template", io.result.search)
                        io.step = 5
                    }
                }

                // 4: working
                Row {
                    visible: io.step === 4
                    spacing: 10
                    DotLoader { anchors.verticalCenter: parent.verticalCenter }
                    Text { text: qsTr("Importing…"); color: Theme.fg; font.pixelSize: Theme.px(13) }
                }

                // 5: summary
                ColumnLayout {
                    visible: io.step === 5
                    spacing: 8
                    Row {
                        spacing: 8
                        Rectangle { width: 22; height: 22; radius: 11; color: Theme.accent; Icon { anchors.centerIn: parent; glyph: "check"; color: Theme.textOnAccent; sourceSize: Qt.size(14, 14) } }
                        Text { text: qsTr("Done"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        text: io.result ? qsTr("Added %1 bookmarks and %2 pages of history.").arg(io.number(io.result.bookmarks)).arg(io.number(io.result.history))
                                            + (io.what.search && io.result.search ? " " + qsTr("Search engine set.") : "") : ""
                        color: Theme.fg
                        font.pixelSize: Theme.px(13)
                    }
                    Text { visible: io.result && io.result.error !== undefined; text: io.result && io.result.error ? io.result.error : ""; color: Theme.accent2; font.pixelSize: Theme.px(12) }
                    Ui.Pill { text: qsTr("Import something else"); onClicked: io.step = 0 }
                }
                Text { id: htmlResult; visible: text !== "" && io.step === 0; color: Theme.fg; font.pixelSize: Theme.px(13) }
            }
        }
    }
    FileDialog {
        id: htmlDialog
        nameFilters: [qsTr("Bookmark files (*.html *.htm)")]
        onAccepted: {
            const n = Browser.library.importBookmarksHtml(selectedFile)
            htmlResult.text = n < 0 ? qsTr("That file couldn't be read.") : qsTr("Added %1 bookmarks.").arg(n)
        }
    }

    // ---------- export ----------
    Ui.Section {
        title: qsTr("Export")
        Ui.SettingRow {
            label: qsTr("Bookmarks")
            hint: qsTr("An HTML file any browser can import")
            Ui.Pill { text: qsTr("Export…"); onClicked: { saveDialog.kind = "bookmarks"; saveDialog.open() } }
        }
        Ui.SettingRow {
            label: qsTr("History")
            hint: qsTr("A CSV file (address, title, last visit, visits)")
            Ui.Pill { text: qsTr("Export…"); onClicked: { saveDialog.kind = "history"; saveDialog.open() } }
        }
        Ui.SettingRow {
            label: qsTr("Themes")
            hint: qsTr("Each saved theme exports from its menu in Appearance")
        }
        Ui.SettingRow {
            label: qsTr("Passwords")
            hint: qsTr("Only from Passwords, after confirming it's you: the file isn't encrypted")
            last: true
            Ui.Pill { text: qsTr("Passwords"); onClicked: io.openPasswords() }
        }
    }

    // ---------- backup ----------
    Ui.Section {
        title: qsTr("Backup and restore")
        Ui.SettingRow {
            label: qsTr("Include history in backups")
            Ui.Toggle { id: withHistory; checked: false }
        }
        Ui.SettingRow {
            label: qsTr("Back up f1int")
            hint: qsTr("Settings, look, saved themes, new tab page and bookmarks in one file. Passwords are never included.")
            Ui.Pill { text: qsTr("Back up…"); onClicked: { saveDialog.kind = "backup"; saveDialog.open() } }
        }
        Ui.SettingRow {
            label: qsTr("Restore a backup")
            hint: restoreMessage
            last: true
            property string restoreMessage: ""
            id: restoreRow
            Ui.Pill { text: qsTr("Restore…"); onClicked: restoreDialog.open() }
        }
    }

    FileDialog {
        id: saveDialog
        property string kind: "bookmarks"
        fileMode: FileDialog.SaveFile
        defaultSuffix: kind === "bookmarks" ? "html" : kind === "history" ? "csv" : "f1backup"
        nameFilters: kind === "bookmarks" ? [qsTr("Bookmark files (*.html)")] : kind === "history" ? [qsTr("CSV files (*.csv)")] : [qsTr("f1int backups (*.f1backup)")]
        currentFile: "file:///" + (kind === "bookmarks" ? "bookmarks.html" : kind === "history" ? "history.csv" : "f1int-backup.f1backup")
        onAccepted: {
            let ok = false
            if (kind === "bookmarks") ok = Browser.library.exportBookmarksHtml(selectedFile)
            else if (kind === "history") {
                const q = (s) => '"' + String(s === undefined ? "" : s).replace(/"/g, '""') + '"'
                const rows = Browser.library.history("", 1000000).map(h => [q(h.url), q(h.title), q(new Date(Number(h.last_visit)).toISOString()), q(h.visits)].join(","))
                ok = Browser.writeTextFile(selectedFile, "url,title,last_visit,visits\n" + rows.join("\n"))
            } else {
                const backup = { format: "f1int-backup", version: 1, created: new Date().toISOString(), settings: Browser.settingsForBackup(),
                                 bookmarks: Browser.library.bookmarks() }
                if (withHistory.checked) backup.history = Browser.library.history("", 1000000)
                ok = Browser.writeTextFile(selectedFile, JSON.stringify(backup))
            }
            restoreRow.restoreMessage = ok ? qsTr("Saved.") : qsTr("Couldn't write that file.")
        }
    }
    FileDialog {
        id: restoreDialog
        nameFilters: [qsTr("f1int backups (*.f1backup *.json)")]
        onAccepted: {
            let b = null
            try { b = JSON.parse(Browser.readTextFile(selectedFile)) } catch (e) {}
            if (!b || b.format !== "f1int-backup" || typeof b.settings !== "object") { restoreRow.restoreMessage = qsTr("That isn't an f1int backup."); return }
            confirmRestore.backup = b
            confirmRestore.open()
        }
    }
    Popup {
        id: confirmRestore
        property var backup: null
        anchors.centerIn: Overlay.overlay
        modal: true
        padding: 20
        width: 380
        background: Rectangle { color: Theme.surface; radius: Theme.cardRadius; border.width: 1; border.color: Theme.line }
        contentItem: Column {
            spacing: 12
            Text { text: qsTr("Restore this backup?"); color: Theme.fg; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.dim
                font.pixelSize: Theme.px(13)
                text: confirmRestore.backup ? qsTr("From %1: %2 settings, %3 bookmarks%4. Your current settings are replaced; bookmarks and history are added to what you have.")
                      .arg(new Date(confirmRestore.backup.created).toLocaleDateString()).arg(Object.keys(confirmRestore.backup.settings).length)
                      .arg((confirmRestore.backup.bookmarks || []).length)
                      .arg(confirmRestore.backup.history ? qsTr(", %1 pages of history").arg(confirmRestore.backup.history.length) : "") : ""
            }
            Row {
                spacing: 8
                Ui.Pill {
                    primary: true
                    text: qsTr("Restore")
                    onClicked: {
                        const b = confirmRestore.backup
                        const n = Browser.restoreSettings(b.settings)
                        let added = 0
                        for (const bm of (b.bookmarks || []))
                            if (bm && typeof bm.url === "string" && /^https?:/.test(bm.url) && !Browser.library.isBookmarked(bm.url)) { Browser.library.addBookmark(bm.url, String(bm.title || "")); added++ }
                        const h = Array.isArray(b.history) ? Browser.library.addHistory(b.history) : 0
                        restoreRow.restoreMessage = qsTr("Restored %1 settings, %2 bookmarks and %3 pages of history.").arg(n).arg(added).arg(h)
                        confirmRestore.close()
                    }
                }
                Ui.Pill { text: qsTr("Cancel"); onClicked: confirmRestore.close() }
            }
        }
    }
}
