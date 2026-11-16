import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtWebEngine
import f1int

// One browser window: tab bar on the left, toolbar + page on the right.
ApplicationWindow {
    id: window
    width: 1280
    height: 800
    visible: true
    color: Theme.bg
    title: (view.title || qsTr("New tab")) + " – f1int"

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Left tab bar (placeholder: one tab). Stage 1b replaces this. ----
        Rectangle {
            Layout.preferredWidth: Theme.tabBarWidth
            Layout.fillHeight: true
            color: Theme.bg

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Text {
                    text: qsTr("+  New tab")
                    color: Theme.dim
                    font.pixelSize: 13
                    leftPadding: 8
                    height: 32
                    verticalAlignment: Text.AlignVCenter
                }
                Rectangle {   // the one open tab
                    width: parent.width
                    height: 32
                    radius: Theme.radius
                    color: Theme.hover
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        spacing: 8
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16
                            sourceSize: Qt.size(16, 16)   // decode small: saves RAM
                            source: view.icon
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            text: view.title || qsTr("New tab")
                            color: Theme.fg
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.line }

        // ---- Toolbar, loading bar and the page ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Toolbar { id: toolbar; view: view; Layout.fillWidth: true }

            Item {   // 2px loading bar; the space is always there so the page doesn't jump
                Layout.fillWidth: true
                implicitHeight: 2
                Rectangle {
                    height: parent.height
                    width: parent.width * view.loadProgress / 100
                    color: Theme.accent
                    visible: view.loading
                }
            }

            WebEngineView {
                id: view
                Layout.fillWidth: true
                Layout.fillHeight: true
                profile: Browser.profile
                url: Browser.startUrl

                // Links that want a new window open here until we have tabs (Stage 1b).
                onNewWindowRequested: (request) => view.url = request.requestedUrl
            }
        }
    }

    // ---- Keyboard shortcuts (same as Chrome). On Mac, "Ctrl" means Cmd. ----
    Shortcut { sequences: ["Ctrl+L", "Alt+D", "F6"]; onActivated: toolbar.focusAddress() }
    Shortcut { sequences: ["Alt+Left", "Ctrl+["]; onActivated: view.goBack() }
    Shortcut { sequences: ["Alt+Right", "Ctrl+]"]; onActivated: view.goForward() }
    Shortcut { sequences: ["F5", "Ctrl+R"]; onActivated: view.reload() }
    Shortcut { sequences: ["Ctrl+F5", "Shift+F5", "Ctrl+Shift+R"]; onActivated: view.reloadAndBypassCache() }
    Shortcut { sequence: "Alt+Home"; onActivated: view.url = Browser.homeUrl }
    Shortcut { sequence: "Esc"; enabled: view.loading; onActivated: view.stop() }
}
