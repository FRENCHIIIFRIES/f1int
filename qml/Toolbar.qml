import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtWebEngine
import f1int

// The slim bar above the page: back, forward, reload, home and the address bar.
Rectangle {
    id: bar
    required property WebEngineView view

    function focusAddress() { address.forceActiveFocus(); address.selectAll() }

    implicitHeight: 40
    color: Theme.bg

    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 2

        IconButton { text: "←"; tip: qsTr("Back");    enabled: bar.view.canGoBack;    onClicked: bar.view.goBack() }
        IconButton { text: "→"; tip: qsTr("Forward"); enabled: bar.view.canGoForward; onClicked: bar.view.goForward() }
        IconButton {
            text: bar.view.loading ? "✕" : "↻"
            tip: bar.view.loading ? qsTr("Stop") : qsTr("Reload")
            onClicked: bar.view.loading ? bar.view.stop() : bar.view.reload()
        }
        IconButton { text: "⌂"; tip: qsTr("Home"); onClicked: bar.view.url = Browser.homeUrl }

        TextField {
            id: address
            Layout.fillWidth: true
            Layout.leftMargin: 4
            implicitHeight: 28
            color: Theme.fg
            placeholderText: qsTr("Search or type a web address")
            placeholderTextColor: Theme.dim
            selectByMouse: true
            selectionColor: Theme.accent
            font.pixelSize: 13
            leftPadding: 10
            Accessible.name: qsTr("Address and search bar")

            background: Rectangle {
                radius: Theme.radius
                color: Theme.field
                border.width: 1
                border.color: address.activeFocus ? Theme.dim : Theme.line
            }

            // Show the page's address, except while the user is typing.
            function showPageUrl() { text = bar.view.url.toString() }
            Connections {
                target: bar.view
                function onUrlChanged() { if (!address.activeFocus) address.showPageUrl() }
            }
            Component.onCompleted: showPageUrl()

            onAccepted: {
                const url = Browser.urlFromInput(text)
                if (url.toString() === "")
                    return
                bar.view.url = url
                bar.view.forceActiveFocus()   // hand the keyboard back to the page
            }
            onActiveFocusChanged: {
                if (activeFocus) selectAll()
                else showPageUrl()            // typed but didn't press Enter: put the URL back
            }
            Keys.onEscapePressed: { showPageUrl(); bar.view.forceActiveFocus() }
        }
    }
}
