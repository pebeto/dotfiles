import QtQuick
import qs

// A clickable stretch of the bar holding one or more Segments. It lights up
// on hover and passes clicks and whole wheel notches on as signals.
Item {
    id: root

    default property alias content: row.data
    property bool interactive: true
    readonly property bool hovered: mouse.containsMouse

    signal clicked(int button)
    signal doubleClicked(int button)
    signal wheel(int steps)

    implicitWidth: row.implicitWidth + Theme.gap * 2
    implicitHeight: Theme.barHeight

    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.round(Theme.em * 0.15)
        radius: Math.round(Theme.radius * 0.6)
        color: root.interactive && mouse.containsMouse ? Theme.hover : "transparent"
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(Theme.em * 0.6)
    }

    MouseArea {
        id: mouse

        // Touchpads send many small deltas, so steps are counted per 120
        // units (one mouse-wheel notch).
        property real wheelAcc: 0

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => root.clicked(e.button)
        onDoubleClicked: e => root.doubleClicked(e.button)
        onWheel: e => {
            wheelAcc += e.angleDelta.y;
            const steps = Math.trunc(wheelAcc / 120);
            if (steps !== 0) {
                wheelAcc -= steps * 120;
                root.wheel(steps);
            }
        }
    }
}
