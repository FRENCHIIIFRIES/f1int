import QtQuick
import QtQuick.Controls.impl
import f1int

// One of our line icons (resources/icons/<name>.svg), tinted to any colour.
IconImage {
    property string glyph
    // Drawn by f1int's icon renderer: any stroke weight, or your own icon pack (Appearance).
    source: Theme.iconSource(glyph)
    sourceSize: Qt.size(16, 16)
    color: Theme.iconColor
}
