import QtQuick
import qs

// A row in a list of sound devices to pick from: an icon and a name, the
// current one checked and highlighted.
Rectangle {
    id: row

    property string icon: ""
    property string label: ""
    property bool current: false

    signal clicked

    height: Math.round(Theme.em * 1.7)
    radius: Math.round(Theme.radius * 0.6)
    color: current ? Theme.highlight : mouse.containsMouse ? Theme.paperHover : "transparent"

    Row {
        x: Math.round(Theme.gap * 0.6)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Glyph {
            text: row.icon
            color: Theme.ink
        }
        Ink {
            text: row.label
            font.bold: row.current
        }
    }

    Glyph {
        anchors.right: parent.right
        anchors.rightMargin: Math.round(Theme.gap * 0.6)
        anchors.verticalCenter: parent.verticalCenter
        visible: row.current
        text: Theme.icons.check
        color: Theme.ink
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
