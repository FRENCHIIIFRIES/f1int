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
    signal menuRequested(Item button)
    signal panelRequested(string name)

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

    implicitHeight: 46
    color: Theme.bg

    // Network indicator: lights up while the open tab's site is sending requests.
    Connections {
        target: Browser
        function onSiteActivity(host) {
            if (bar.view && bar.view.url.toString().indexOf("//" + host) > 0) activity.pulse()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 2

        IconButton { iconName: "back";    tip: qsTr("Back (Alt+Left)");     enabled: bar.view && bar.view.canGoBack;    onClicked: bar.view.goBack() }
        IconButton { iconName: "forward"; tip: qsTr("Forward (Alt+Right)"); enabled: bar.view && bar.view.canGoForward; onClicked: bar.view.goForward() }
        IconButton {
            readonly property bool loading: bar.view !== null && bar.view.loading
            iconName: loading ? "stop" : "reload"
            tip: loading ? qsTr("Stop (Esc)") : qsTr("Reload (F5)")
            enabled: bar.view !== null
            onClicked: loading ? bar.view.stop() : bar.view.reload()
        }
        IconButton { iconName: "home"; tip: qsTr("Home (Alt+Home)"); enabled: bar.view !== null; onClicked: bar.view.url = Browser.homeUrl }

        // Incognito badge
        Rectangle {
            visible: bar.incognito
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
                Text { text: qsTr("Incognito"); color: Theme.fg; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        TextField {
            id: address
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            implicitHeight: 32
            leftPadding: 34
            rightPadding: 60
            color: Theme.fg
            placeholderText: qsTr("Search or type a web address")
            placeholderTextColor: Theme.dim
            selectByMouse: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            font.pixelSize: 13
            Accessible.name: qsTr("Address and search bar")

            background: Rectangle {
                radius: Theme.radius
                color: Theme.surface
                border.width: 1
                border.color: address.activeFocus ? Theme.dim : Theme.line
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
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        MouseArea { anchors.fill: parent; onClicked: bar.go(modelData.url) }
                    }
                }
            }
        }

        // Downloads: shows a red dot while something is downloading.
        IconButton {
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
        visible: width > 0
        Behavior on width { NumberAnimation { duration: Theme.anim } }
    }
}
