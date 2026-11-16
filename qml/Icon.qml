import QtQuick
import QtQuick.Controls.impl
import f1int

// One of our line icons (resources/icons/<name>.svg), tinted to any colour.
IconImage {
    property string glyph
    source: glyph ? "qrc:/icons/" + glyph + ".svg" : ""
    sourceSize: Qt.size(16, 16)
    color: Theme.fg
}
