import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtWebEngine
import f1int

// Right-hand panel with Bookmarks, History and Downloads.
Rectangle {
    id: panel
    property string page: "bookmarks"   // bookmarks | history | downloads
    property var downloads: []          // download requests from this window, newest first
    property bool embedded: false       // inside Settings: no side-panel edge
    signal openUrl(url url)
    signal closeRequested()

    function niceTime(ms) { return new Date(ms).toLocaleString(Qt.locale(), Locale.ShortFormat) }
    function size(bytes) {
        return bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(bytes / 1024)) + " KB"
    }
    readonly property var rows: {
        void Browser.library.revision   // refresh when bookmarks/history change
        if (page === "bookmarks") return Browser.library.bookmarks(search.text)
        if (page !== "history") return []
        // History, with a heading row before each day: Today, Yesterday, then dates.
        const out = []
        let last = ""
        const today = new Date(); today.setHours(0, 0, 0, 0)
        for (const h of Browser.library.history(search.text, 500)) {
            const d = new Date(Number(h.time)); d.setHours(0, 0, 0, 0)
            const days = Math.round((today - d) / 86400000)
            const label = days === 0 ? qsTr("Today") : days === 1 ? qsTr("Yesterday") : d.toLocaleDateString(Qt.locale(), "dddd d MMMM")
            if (label !== last) { out.push({ heading: label }); last = label }
            out.push(h)
        }
        return out
    }
    // Downloads: this window's (live) first, then the remembered ones from before.
    readonly property var pastDownloads: {
        void Browser.settingsRevision
        let list = []
        try { list = JSON.parse(String(Browser.setting("downloads/history", "[]"))) } catch (e) {}
        const live = downloads.map(d => d.downloadDirectory + "/" + d.downloadFileName)
        return list.filter(x => live.indexOf(x.path) < 0)
    }
    function forgetDownload(path) {
        let list = []
        try { list = JSON.parse(String(Browser.setting("downloads/history", "[]"))) } catch (e) {}
        Browser.setSetting("downloads/history", JSON.stringify(list.filter(x => x.path !== path)))
    }

    color: Theme.surface
    Rectangle { visible: !panel.embedded; width: 1; height: parent.height; color: Theme.line }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Ui.Heading { text: ({ bookmarks: qsTr("Bookmarks"), history: qsTr("History"), downloads: qsTr("Downloads") })[panel.page] || "" }
            Item { Layout.fillWidth: true }
            IconButton { iconName: "close"; tip: qsTr("Close"); onClicked: panel.closeRequested() }
        }

        Ui.Field {
            id: search
            visible: panel.page !== "downloads"
            Layout.fillWidth: true
            placeholderText: panel.page === "bookmarks" ? qsTr("Search bookmarks") : qsTr("Search history")
        }

        // ---- bookmarks and history ----
        ListView {
            id: list
            visible: panel.page !== "downloads"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: panel.rows
            ScrollBar.vertical: ScrollBar { width: 4 }
            delegate: Rectangle {
                required property var modelData
                readonly property bool heading: modelData.heading !== undefined
                width: ListView.view.width
                height: heading ? 36 : 58
                Text {   // a day heading in history
                    visible: parent.heading
                    x: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: parent.heading ? parent.modelData.heading : ""
                    color: Theme.fg
                    opacity: 0.75
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.DemiBold
                }
                radius: 8
                color: rowHover.hovered && !heading ? Theme.hover : "transparent"
                HoverHandler { id: rowHover }
                Image {   // the site's own icon (Browser.favicons), else a plain one
                    id: siteIcon
                    visible: !parent.heading && status === Image.Ready
                    x: 10
                    width: 16; height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    sourceSize: Qt.size(32, 32)
                    source: parent.heading ? "" : (void Browser.favicons.revision, Browser.favicons.icon(modelData.url))
                }
                Icon {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !siteIcon.visible && !parent.heading
                    glyph: panel.page === "bookmarks" ? "star" : "history"
                    color: Theme.dim
                }
                ColumnLayout {
                    visible: !parent.heading
                    anchors.left: parent.left
                    anchors.leftMargin: 36
                    anchors.right: renameButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: modelData.title || modelData.url || ""; color: Theme.fg; font.pixelSize: Theme.px(14); elide: Text.ElideRight; Layout.fillWidth: true }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: String(modelData.url || "").replace(/^https?:\/\/(www\.)?/, "")
                            color: Theme.dim
                            font.pixelSize: Theme.px(12)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {   // when it was visited
                            visible: panel.page === "history"
                            text: new Date(Number(modelData.time)).toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
                            color: Theme.dim
                            font.family: Theme.numberFont
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.Bold
                        }
                    }
                }
                MouseArea { anchors.fill: parent; enabled: !parent.heading; onClicked: panel.openUrl(modelData.url) }
                IconButton {   // bookmarks only: change the name
                    id: renameButton
                    anchors.right: remove.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowHover.hovered && panel.page === "bookmarks"
                    iconName: "edit"
                    tip: qsTr("Rename")
                    onClicked: renameBox.openFor(modelData)
                }
                IconButton {
                    id: remove
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowHover.hovered && !parent.heading
                    iconName: "trash"
                    tip: panel.page === "bookmarks" ? qsTr("Remove bookmark") : qsTr("Remove from history")
                    onClicked: panel.page === "bookmarks" ? Browser.library.removeBookmark(modelData.url)
                                                          : Browser.library.removeHistory(modelData.url)
                }
            }
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: panel.page === "bookmarks" ? qsTr("No bookmarks yet.\nClick ☆ in the address bar (Ctrl+D).") : qsTr("No history.")
                color: Theme.dim
                font.pixelSize: Theme.px(12)
            }
        }
        RenameBookmark { id: renameBox }
        Ui.Pill {
            visible: panel.page === "history" && list.count > 0
            text: qsTr("Clear all history")
            onClicked: Browser.library.clearHistory()
        }

        // ---- downloads ----
        Flickable {
            visible: panel.page === "downloads"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: downloadColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { width: 4 }
            Column {
                id: downloadColumn
                width: parent.width
                spacing: 6
        Repeater {
            id: downloadList
            model: panel.downloads
            delegate: Rectangle {
                id: item
                required property var modelData
                readonly property bool done: modelData.state === WebEngineDownloadRequest.DownloadCompleted
                readonly property bool failed: modelData.state === WebEngineDownloadRequest.DownloadCancelled
                                               || modelData.state === WebEngineDownloadRequest.DownloadInterrupted
                readonly property string path: modelData.downloadDirectory + "/" + modelData.downloadFileName
                width: downloadColumn.width
                height: 68
                radius: Theme.radius + 2
                color: Theme.bg
                border.width: 1
                border.color: Theme.line
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: item.modelData.downloadFileName; color: Theme.fg; font.pixelSize: Theme.px(13); elide: Text.ElideMiddle; Layout.fillWidth: true }
                        IconButton { visible: item.done; iconName: "folder"; tip: qsTr("Show in folder"); onClicked: Browser.showInFolder(item.path) }
                        IconButton { visible: !item.done && !item.failed; iconName: "close"; tip: qsTr("Cancel"); onClicked: item.modelData.cancel() }
                    }
                    Rectangle {   // progress bar
                        visible: !item.done && !item.failed
                        Layout.fillWidth: true
                        height: 3
                        radius: 1.5
                        color: Theme.line
                        Rectangle {
                            height: parent.height
                            radius: 1.5
                            color: Theme.accent
                            width: item.modelData.totalBytes > 0 ? parent.width * item.modelData.receivedBytes / item.modelData.totalBytes : 0
                        }
                    }
                    Text {
                        text: item.failed ? qsTr("Cancelled")
                              : item.done ? qsTr("Done, %1").arg(panel.size(item.modelData.totalBytes))
                              : panel.size(item.modelData.receivedBytes) + (item.modelData.totalBytes > 0 ? " / " + panel.size(item.modelData.totalBytes) : "")
                        color: item.failed ? Theme.accent2 : Theme.dim
                        font.pixelSize: Theme.px(12)
                    }
                }
                MouseArea {   // click a finished download to open it
                    anchors.fill: parent
                    z: -1
                    enabled: item.done
                    onClicked: Qt.openUrlExternally(Browser.fileUrl(item.path))
                }
            }
        }
                Text {
                    visible: panel.pastDownloads.length > 0
                    topPadding: downloadList.count > 0 ? 10 : 0
                    text: qsTr("Earlier")
                    color: Theme.fg
                    opacity: 0.75
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.DemiBold
                }
                Repeater {   // remembered from before (the file may have moved since)
                    model: panel.pastDownloads
                    Rectangle {
                        id: past
                        required property var modelData
                        readonly property bool there: { void Browser.settingsRevision; return Browser.fileExists(modelData.path) }
                        width: downloadColumn.width
                        height: 58
                        radius: Theme.radius + 2
                        color: pastHover.hovered ? Theme.hover : "transparent"
                        HoverHandler { id: pastHover; cursorShape: past.there ? Qt.PointingHandCursor : Qt.ArrowCursor }
                        Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; glyph: "download"; color: Theme.dim }
                        Column {
                            x: 40
                            width: parent.width - 40 - (pastButtons.visible ? pastButtons.width + 8 : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            Text { width: parent.width; text: past.modelData.name; color: past.there ? Theme.fg : Theme.dim; font.pixelSize: Theme.px(14); elide: Text.ElideMiddle; font.strikeout: !past.there }
                            Text {
                                width: parent.width
                                text: (past.there ? panel.size(past.modelData.size) : qsTr("Deleted or moved")) + "  ·  "
                                      + new Date(past.modelData.time).toLocaleDateString(Qt.locale(), Locale.ShortFormat)
                                      + "  ·  " + String(past.modelData.url).replace(/^https?:\/\/(www\.)?/, "").split("/")[0]
                                color: Theme.dim
                                font.pixelSize: Theme.px(12)
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea { anchors.fill: parent; enabled: past.there; onClicked: Qt.openUrlExternally(Browser.fileUrl(past.modelData.path)) }
                        Row {
                            id: pastButtons
                            visible: pastHover.hovered
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            IconButton { visible: past.there; iconName: "folder"; tip: qsTr("Show in folder"); onClicked: Browser.showInFolder(past.modelData.path) }
                            IconButton { iconName: "close"; tip: qsTr("Remove from the list"); onClicked: panel.forgetDownload(past.modelData.path) }
                        }
                    }
                }
                Text {
                    visible: downloadList.count === 0 && panel.pastDownloads.length === 0
                    width: parent.width
                    topPadding: 60
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("No downloads yet.")
                    color: Theme.dim
                    font.pixelSize: Theme.px(13)
                }
            }
        }
    }
}
