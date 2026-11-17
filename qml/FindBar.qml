import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtWebEngine
import f1int

// Find in page (Ctrl+F): Enter = next match, Shift+Enter = previous, Esc = close.
Rectangle {
    id: bar
    property WebEngineView view: null
    property int matches: 0
    property int current: 0

    function open() {
        visible = true
        field.forceActiveFocus()
        field.selectAll()
        if (field.text !== "") find(false)
    }
    function close() {
        visible = false
        if (view) { view.findText(""); view.forceActiveFocus() }   // empty search clears the highlights
    }
    function find(backward) {
        if (view) view.findText(field.text, backward ? WebEngineView.FindBackward : 0)
    }

    visible: false
    implicitHeight: visible ? 42 : 0
    color: Theme.bg

    Connections {
        target: bar.view
        function onFindTextFinished(result) { bar.matches = result.numberOfMatches; bar.current = result.activeMatch }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 6
        Icon { glyph: "find"; color: Theme.dim }
        Ui.Field {
            id: field
            Layout.preferredWidth: 280
            placeholderText: qsTr("Find in page")
            onTextEdited: bar.find(false)
            Keys.onReturnPressed: (e) => bar.find(e.modifiers & Qt.ShiftModifier)
            Keys.onEscapePressed: bar.close()
        }
        Text {
            text: field.text === "" ? "" : bar.matches === 0 ? qsTr("No matches") : bar.current + "/" + bar.matches
            color: bar.matches === 0 && field.text !== "" ? Theme.accent : Theme.fg
            font.family: bar.matches > 0 ? Theme.dotFont : ""
            font.pixelSize: bar.matches > 0 ? 16 : 12
            font.weight: Font.Bold
        }
        Item { Layout.fillWidth: true }
        IconButton { iconName: "up"; tip: qsTr("Previous (Shift+Enter)"); onClicked: bar.find(true) }
        IconButton { iconName: "down"; tip: qsTr("Next (Enter)"); onClicked: bar.find(false) }
        IconButton { iconName: "close"; tip: qsTr("Close (Esc)"); onClicked: bar.close() }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
}
