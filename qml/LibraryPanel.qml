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
    signal openUrl(url url)
    signal closeRequested()

    function niceTime(ms) { return new Date(ms).toLocaleString(Qt.locale(), Locale.ShortFormat) }
    function size(bytes) {
        return bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(bytes / 1024)) + " KB"
    }
    readonly property var rows: {
        void Browser.library.revision   // refresh when bookmarks/history change
        if (page === "bookmarks") return Browser.library.bookmarks(search.text)
        if (page === "history") return Browser.library.history(search.text)
        return []
    }

    color: Theme.surface
    Rectangle { width: 1; height: parent.height; color: Theme.line }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Ui.Heading { text: panel.page.charAt(0).toUpperCase() + panel.page.slice(1) }
            Item { Layout.fillWidth: true }
            IconButton { iconName: "close"; tip: qsTr("Close"); onClicked: panel.closeRequested() }
        }
        Ui.Segmented {
            options: [{ label: qsTr("Bookmarks"), value: "bookmarks" }, { label: qsTr("History"), value: "history" },
                      { label: qsTr("Downloads"), value: "downloads" }]
            value: panel.page
            onPicked: (v) => panel.page = v
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
                width: ListView.view.width
                height: 50
                radius: 8
                color: rowHover.hovered ? Theme.hover : "transparent"
                HoverHandler { id: rowHover }
                Image {   // the site's own icon (Browser.favicons), else a plain one
                    id: siteIcon
                    x: 10
                    width: 16; height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    sourceSize: Qt.size(32, 32)
                    source: { void Browser.favicons.revision; return Browser.favicons.icon(modelData.url) }
                    visible: status === Image.Ready
                }
                Icon {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !siteIcon.visible
                    glyph: panel.page === "bookmarks" ? "star" : "history"
                    color: Theme.dim
                }
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.leftMargin: 36
                    anchors.right: remove.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: modelData.title || modelData.url; color: Theme.fg; font.pixelSize: Theme.px(13); elide: Text.ElideRight; Layout.fillWidth: true }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: modelData.url.replace(/^https?:\/\/(www\.)?/, "")
                            color: Theme.dim
                            font.pixelSize: Theme.px(11)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {   // when it was visited
                            visible: panel.page === "history"
                            text: panel.niceTime(modelData.time)
                            color: Theme.dim
                            font.family: Theme.numberFont
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.Bold
                        }
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: panel.openUrl(modelData.url) }
                IconButton {
                    id: remove
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowHover.hovered
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
        Ui.Pill {
            visible: panel.page === "history" && list.count > 0
            text: qsTr("Clear all history")
            onClicked: Browser.library.clearHistory()
        }

        // ---- downloads ----
        ListView {
            id: downloadList
            visible: panel.page === "downloads"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: panel.downloads
            delegate: Rectangle {
                id: item
                required property var modelData
                readonly property bool done: modelData.state === WebEngineDownloadRequest.DownloadCompleted
                readonly property bool failed: modelData.state === WebEngineDownloadRequest.DownloadCancelled
                                               || modelData.state === WebEngineDownloadRequest.DownloadInterrupted
                readonly property string path: modelData.downloadDirectory + "/" + modelData.downloadFileName
                width: ListView.view.width
                height: 64
                radius: 10
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
                        IconButton { visible: item.done; iconName: "folder"; tip: qsTr("Show in folder"); onClicked: Qt.openUrlExternally(Browser.fileUrl(item.modelData.downloadDirectory)) }
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
                        color: item.failed ? Theme.accent : Theme.dim
                        font.pixelSize: Theme.px(11)
                    }
                }
                MouseArea {   // click a finished download to open it
                    anchors.fill: parent
                    z: -1
                    enabled: item.done
                    onClicked: Qt.openUrlExternally(Browser.fileUrl(item.path))
                }
            }
            Text {
                anchors.centerIn: parent
                visible: downloadList.count === 0
                text: qsTr("No downloads yet.")
                color: Theme.dim
                font.pixelSize: Theme.px(12)
            }
        }
    }
}
