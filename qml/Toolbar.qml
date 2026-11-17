import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtWebEngine
import f1int

// The slim bar above the page: back, forward, reload, home, address bar (with star,
// network activity dot and suggestions), downloads and the menu.
Rectangle {
    id: bar
    property WebEngineView view: null   // the open tab's page (none while switching)
    property bool incognito: false
    property int activeDownloads: 0
    // Stacked: two rows (buttons, then a full-width address bar), for the top of the tab bar.
    property bool stacked: false
    signal menuRequested(Item button)
    signal panelRequested(string name)
    signal keyRequested(Item button)

    function focusAddress() { address.forceActiveFocus(); address.selectAll() }
    function toggleBookmark() {
        if (!view || prettyUrl(view.url) === "") return
        Browser.library.isBookmarked(view.url) ? Browser.library.removeBookmark(view.url)
                                               : Browser.library.addBookmark(view.url, view.title)
    }
    // "https://www.example.com/" -> "example.com" while not editing; blank for empty tabs.
    function prettyUrl(u) {
        const s = u ? u.toString() : ""
        if (s === "" || s === "about:blank") return ""
        return s.replace(/^https?:\/\/(www\.)?/, "").replace(/\/$/, "")
    }
    function go(url) {
        suggestions.close()
        if (!view || url.toString() === "") return
        view.url = url
        view.forceActiveFocus()   // hand the keyboard back to the page
    }

    implicitHeight: stacked ? 82 : 46
    color: "transparent"

    // Network indicator: lights up while the open tab's site is sending requests.
    Connections {
        target: Browser
        function onSiteActivity(host) {
            if (bar.view && bar.view.url.toString().indexOf("//" + host) > 0) activity.pulse()
        }
    }

    GridLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: bar.stacked ? 6 : 0
        anchors.bottomMargin: bar.stacked ? 6 : 0
        columnSpacing: 2
        rowSpacing: 6

        IconButton { Layout.row: 0; Layout.column: 0; iconName: "back";    tip: qsTr("Back (Alt+Left)");     enabled: bar.view && bar.view.canGoBack;    onClicked: bar.view.goBack() }
        IconButton { Layout.row: 0; Layout.column: 1; iconName: "forward"; tip: qsTr("Forward (Alt+Right)"); enabled: bar.view && bar.view.canGoForward; onClicked: bar.view.goForward() }
        IconButton {
            Layout.row: 0
            Layout.column: 2
            readonly property bool loading: bar.view !== null && bar.view.loading
            iconName: loading ? "stop" : "reload"
            tip: loading ? qsTr("Stop (Esc)") : qsTr("Reload (F5)")
            enabled: bar.view !== null
            onClicked: loading ? bar.view.stop() : bar.view.reload()
        }
        IconButton { Layout.row: 0; Layout.column: 3; visible: Theme.showHome; iconName: "home"; tip: qsTr("Home (Alt+Home)"); enabled: bar.view !== null; onClicked: bar.view.url = Browser.homeUrl }

        // Incognito badge
        Rectangle {
            visible: bar.incognito
            Layout.row: 0
            Layout.column: 4
            Layout.leftMargin: 6
            implicitWidth: incognitoRow.implicitWidth + 16
            implicitHeight: 26
            radius: 13
            color: Theme.selected
            Row {
                id: incognitoRow
                anchors.centerIn: parent
                spacing: 6
                Icon { glyph: "incognito"; sourceSize: Qt.size(14, 14); anchors.verticalCenter: parent.verticalCenter }
                Text { text: qsTr("Incognito"); color: Theme.fg; font.pixelSize: Theme.px(11); anchors.verticalCenter: parent.verticalCenter }
            }
        }

        TextField {
            id: address
            Layout.row: bar.stacked ? 1 : 0
            Layout.column: bar.stacked ? 0 : 5
            Layout.columnSpan: bar.stacked ? 8 : 1
            Layout.fillWidth: true
            Layout.leftMargin: bar.stacked ? 0 : 6
            Layout.rightMargin: bar.stacked ? 0 : 6
            implicitHeight: Theme.rowHeight
            leftPadding: 34
            rightPadding: 122   // room for the activity dot, key, reading view and star
            color: Theme.fg
            placeholderText: qsTr("Search or enter address")
            placeholderTextColor: Theme.dim
            selectByMouse: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.textOnAccent
            font.pixelSize: Theme.px(13)
            Accessible.name: qsTr("Address and search bar")

            background: Rectangle {
                radius: Theme.radius   // (Settings > Appearance > Corners)
                color: Theme.field
                border.width: 1
                border.color: address.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55) : "transparent"   // soft outline only while typing
                Behavior on border.color { ColorAnimation { duration: Theme.anim } }
            }
            // Padlock on secure (https) pages, magnifier otherwise.
            Icon {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                sourceSize: Qt.size(14, 14)
                readonly property bool secure: bar.view !== null && bar.view.url.toString().startsWith("https://")
                glyph: secure && !address.activeFocus ? "lock" : "search"
                color: Theme.dim
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                // Network activity dot
                Rectangle {
                    id: activity
                    function pulse() { opacity = 1; fade.restart() }
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.accent
                    opacity: 0
                    NumberAnimation on opacity { id: fade; running: false; to: 0; duration: 700 }
                    ToolTip.text: qsTr("This site is sending requests")
                    HoverHandler { id: activityHover }
                    ToolTip.visible: activityHover.hovered
                }
                IconButton {   // saved logins for this site (shown where there's a login box)
                    id: keyButton
                    implicitWidth: 26
                    implicitHeight: 26
                    iconSize: 15
                    visible: bar.view !== null && bar.view.hasLoginForm
                    iconName: "key"
                    iconColor: Browser.passwords.state === "unlocked" ? Theme.fg : Theme.dim
                    tip: qsTr("Passwords for this site")
                    onClicked: bar.keyRequested(keyButton)
                }
                IconButton {   // reading view: just the article, in a clean layout (F9)
                    implicitWidth: 26
                    implicitHeight: 26
                    iconSize: 15
                    visible: bar.view !== null && bar.prettyUrl(bar.view.url) !== ""
                    iconName: "reader"
                    iconColor: bar.view && bar.view.readerOn ? Theme.accent : Theme.dim
                    tip: bar.view && bar.view.readerOn ? qsTr("Close reading view (F9)") : qsTr("Reading view (F9)")
                    onClicked: bar.view.reader(!bar.view.readerOn)
                }
                IconButton {
                    readonly property bool starred: { void Browser.library.revision; return bar.view !== null && Browser.library.isBookmarked(bar.view.url) }
                    implicitWidth: 26
                    implicitHeight: 26
                    iconSize: 15
                    visible: bar.view !== null && bar.prettyUrl(bar.view.url) !== ""
                    iconName: starred ? "star-filled" : "star"
                    iconColor: starred ? Theme.accent : Theme.dim
                    tip: starred ? qsTr("Remove bookmark (Ctrl+D)") : qsTr("Bookmark this page (Ctrl+D)")
                    onClicked: bar.toggleBookmark()
                }
            }

            // Show the page's address, except while the user is typing.
            function showPageUrl() {
                const blank = !bar.view || bar.prettyUrl(bar.view.url) === ""
                text = blank ? "" : activeFocus ? bar.view.url.toString() : bar.prettyUrl(bar.view.url)
            }
            Connections {
                target: bar.view
                function onUrlChanged() { if (!address.activeFocus) address.showPageUrl() }
            }
            Connections {
                target: bar
                function onViewChanged() { address.showPageUrl() }
            }

            onTextEdited: suggestions.update(text)
            onAccepted: {
                const pick = suggestions.opened && suggestionList.currentIndex >= 0 ? suggestions.items[suggestionList.currentIndex] : null
                bar.go(pick ? pick.url : Browser.urlFromInput(text))
            }
            onActiveFocusChanged: {
                showPageUrl()                 // full address while editing, short one otherwise
                if (activeFocus) selectAll()
                else suggestions.close()
            }
            Keys.onEscapePressed: { suggestions.close(); showPageUrl(); if (bar.view) bar.view.forceActiveFocus() }
            Keys.onDownPressed: if (suggestions.opened) suggestionList.incrementCurrentIndex()
            Keys.onUpPressed: if (suggestions.opened) suggestionList.decrementCurrentIndex()

            // Suggestions from bookmarks and history, under the address bar.
            Popup {
                id: suggestions
                property var items: []
                function update(text) {
                    items = Browser.library.suggest(text, 6)
                    suggestionList.currentIndex = -1
                    items.length > 0 && text.trim() !== "" ? open() : close()
                }
                y: address.height + 4
                width: address.width
                padding: 6
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                background: Rectangle { color: Theme.surface; radius: Theme.radius; border.width: 1; border.color: Theme.line }
                contentItem: ListView {
                    id: suggestionList
                    implicitHeight: contentHeight
                    interactive: false
                    model: suggestions.items
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: 34
                        radius: 6
                        color: ListView.isCurrentItem || sugHover.hovered ? Theme.hover : "transparent"
                        HoverHandler { id: sugHover }
                        Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; glyph: modelData.bookmark ? "star" : "history"; color: Theme.dim; sourceSize: Qt.size(14, 14) }
                        Text {
                            x: 34
                            width: parent.width - 44
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.StyledText
                            text: (modelData.title || "").replace(/</g, "&lt;") + "  <font color='" + Theme.dim + "'>" + bar.prettyUrl(modelData.url) + "</font>"
                            color: Theme.fg
                            font.pixelSize: Theme.px(12)
                            elide: Text.ElideRight
                        }
                        MouseArea { anchors.fill: parent; onClicked: bar.go(modelData.url) }
                    }
                }
            }
        }

        Item { visible: bar.stacked; Layout.row: 0; Layout.column: 5; Layout.fillWidth: true }   // pushes the right-hand buttons over

        // Downloads: shows a red dot while something is downloading.
        IconButton {
            Layout.row: 0
            Layout.column: 6
            visible: Theme.showDownloads || bar.activeDownloads > 0
            iconName: "download"
            tip: qsTr("Downloads (Ctrl+J)")
            onClicked: bar.panelRequested("downloads")
            Rectangle {
                visible: bar.activeDownloads > 0
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 5
                width: 6
                height: 6
                radius: 3
                color: Theme.accent
            }
        }
        IconButton {
            id: more
            Layout.row: 0
            Layout.column: 7
            iconName: "more"
            tip: qsTr("Menu")
            onClicked: bar.menuRequested(more)
        }
    }

    // Loading progress: a 2px line in the accent colour along the bottom edge.
    Rectangle {
        anchors.bottom: parent.bottom
        width: bar.view && bar.view.loading ? parent.width * bar.view.loadProgress / 100 : 0
        height: 2
        color: Theme.accent
        visible: width > 0 && !bar.stacked   // in the tab bar, the page card shows progress instead
        Behavior on width { NumberAnimation { duration: Theme.anim } }
    }
}
