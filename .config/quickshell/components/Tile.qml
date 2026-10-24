import QtQuick
import qs

// A Control Center toggle: a glyph over a label and a smaller detail line,
// filled in the accent color while on. Some offer more on a right click.
Rectangle {
    id: tile

    property string icon: ""
    property string label: ""
    property string detail: ""
    property bool on: false

    signal clicked
    signal rightClicked

    implicitHeight: Math.round(Theme.em * 4.2)
    radius: Theme.radius
    color: on ? Theme.accent : mouse.containsMouse ? Theme.highlight : Theme.paperHover

    Column {
        anchors.centerIn: parent
        width: parent.width - Theme.gap
        spacing: Math.round(Theme.gap * 0.3)

        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.icon
            color: tile.on ? Theme.accentFg : Theme.ink
            font.pixelSize: Math.round(Theme.em * 1.4)
        }
        Ink {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tile.label
            color: tile.on ? Theme.accentFg : Theme.ink
            font.pixelSize: Theme.small
            font.bold: true
            elide: Text.ElideRight
        }
        Ink {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            text: tile.detail
            color: tile.on ? Theme.accentFg : Theme.inkDim
            font.pixelSize: Theme.small
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => e.button === Qt.RightButton ? tile.rightClicked() : tile.clicked()
    }
}
