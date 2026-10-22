import QtQuick
import qs

// A small clickable label on a popup ("Clear", "Connect").
Rectangle {
    id: root

    property string text
    property bool strong: false
    signal clicked

    implicitWidth: label.implicitWidth + Theme.gap * 2
    implicitHeight: label.implicitHeight + Math.round(Theme.gap * 0.6)
    radius: Math.round(Theme.radius * 0.6)
    color: mouse.containsMouse || strong ? Theme.highlight : "transparent"
    border.width: 1
    border.color: mouse.containsMouse || strong ? Theme.rule : "transparent"

    Ink {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: Theme.small
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
