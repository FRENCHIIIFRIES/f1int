import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtWebEngine
import f1int

// The slim bar above the page: back, forward, reload, home, address bar, menu.
Rectangle {
    id: bar
    property WebEngineView view: null   // the open tab's page (none while switching)
    signal menuRequested(Item button)

    function focusAddress() { address.forceActiveFocus(); address.selectAll() }

    // "https://www.example.com/" -> "example.com" while not editing; blank for empty tabs.
    function prettyUrl(u) {
        const s = u ? u.toString() : ""
        if (s === "" || s === "about:blank") return ""
        return s.replace(/^https?:\/\/(www\.)?/, "").replace(/\/$/, "")
    }

    implicitHeight: 46
    color: Theme.bg

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

        TextField {
            id: address
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            implicitHeight: 32
            leftPadding: 34
            color: Theme.fg
            placeholderText: qsTr("Search or type a web address")
            placeholderTextColor: Theme.dim
            selectByMouse: true
            selectionColor: Theme.accent
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

            onAccepted: {
                const url = Browser.urlFromInput(text)
                if (url.toString() === "" || !bar.view)
                    return
                bar.view.url = url
                bar.view.forceActiveFocus()   // hand the keyboard back to the page
            }
            onActiveFocusChanged: {
                showPageUrl()                 // full address while editing, short one otherwise
                if (activeFocus) selectAll()
            }
            Keys.onEscapePressed: { showPageUrl(); if (bar.view) bar.view.forceActiveFocus() }
        }

        IconButton {
            id: more
            iconName: "more"
            tip: qsTr("Menu")
            onClicked: bar.menuRequested(more)
        }
    }

    // Loading progress: a 2px red line along the bottom edge.
    Rectangle {
        anchors.bottom: parent.bottom
        width: bar.view && bar.view.loading ? parent.width * bar.view.loadProgress / 100 : 0
        height: 2
        color: Theme.accent
        visible: width > 0
        Behavior on width { NumberAnimation { duration: Theme.anim } }
    }
}
