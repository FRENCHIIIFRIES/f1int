import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtWebEngine
import f1int

// Memory: how much RAM f1int uses in total, and an estimate per tab.
// Tabs that share a Chromium process split that process's memory between them.
Rectangle {
    id: panel
    property TabModel tabs
    property var pages: ({})      // tab id -> page (only tabs that have been opened)
    signal sleepAllRequested()
    signal closeRequested()

    property var info: ({ total: 0, browser: 0, processes: {} })
    property var rows: []

    function mb(bytes) { return Math.round(bytes / 1048576) }
    function refresh() {
        info = Browser.memoryInfo()
        const sharing = {}   // process id -> how many tabs use it
        for (const id in pages) {
            const pid = pages[id].renderProcessPid
            if (pages[id].lifecycleState !== WebEngineView.LifecycleState.Discarded && pid > 0)
                sharing[pid] = (sharing[pid] || 0) + 1
        }
        const list = []
        for (let r = 0; r < tabs.count; ++r) {
            const id = tabs.idAt(r)
            const tab = tabs.tab(id)
            const page = pages[id]
            let state = qsTr("Not loaded"), bytes = 0
            if (page) {
                const s = page.lifecycleState
                state = s === WebEngineView.LifecycleState.Discarded ? qsTr("Asleep")
                      : s === WebEngineView.LifecycleState.Frozen ? qsTr("Frozen") : qsTr("Active")
                const pid = page.renderProcessPid
                if (s !== WebEngineView.LifecycleState.Discarded && sharing[pid])
                    bytes = (info.processes[String(pid)] || 0) / sharing[pid]
            }
            list.push({ title: tab.title || qsTr("New tab"), state: state, bytes: bytes })
        }
        rows = list.sort((a, b) => b.bytes - a.bytes)
    }

    color: Theme.surface
    Rectangle { width: 1; height: parent.height; color: Theme.line }
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()
    Timer { interval: 2000; repeat: true; running: panel.visible; onTriggered: panel.refresh() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Ui.Heading { text: qsTr("Memory") }
            Item { Layout.fillWidth: true }
            IconButton { iconName: "close"; tip: qsTr("Close"); onClicked: panel.closeRequested() }
        }

        // Big dot-matrix total.
        RowLayout {
            spacing: 6
            Text { text: panel.mb(panel.info.total); color: Theme.fg; font.family: Theme.numberFont; font.pixelSize: Theme.px(64); font.weight: Font.DemiBold }
            Text { text: "MB"; color: Theme.dim; font.family: Theme.numberFont; font.pixelSize: Theme.px(22); Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 10 }
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("All of f1int: the app (%1 MB) plus %2 Chromium helper processes.")
                  .arg(panel.mb(panel.info.browser)).arg(Math.max(0, Object.keys(panel.info.processes).length - 1))
            color: Theme.dim
            font.pixelSize: Theme.px(12)
        }
        DotGrid { Layout.fillWidth: true; Layout.preferredHeight: 18 }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: panel.rows
            spacing: 2
            delegate: Item {
                required property var modelData
                width: ListView.view.width
                height: 40
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true
                        Text { text: modelData.title; color: Theme.fg; font.pixelSize: Theme.px(13); elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: modelData.state; color: modelData.state === qsTr("Active") ? Theme.accent : Theme.dim; font.pixelSize: Theme.px(12) }
                    }
                    Text {
                        text: modelData.bytes > 0 ? "~" + panel.mb(modelData.bytes) + " MB" : "0 MB"
                        color: Theme.fg
                        font.family: Theme.numberFont
                        font.pixelSize: Theme.px(16)
                        font.weight: Font.Bold
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            }
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("%1 ad and tracker requests blocked").arg(Browser.blockedTotal)
            color: Theme.dim
            font.pixelSize: Theme.px(12)
        }
        Ui.Pill {
            Layout.fillWidth: true
            primary: true
            text: qsTr("Sleep all background tabs")
            onClicked: { panel.sleepAllRequested(); refreshLater.start() }
        }
    }
    Timer { id: refreshLater; interval: 1500; onTriggered: panel.refresh() }
}
