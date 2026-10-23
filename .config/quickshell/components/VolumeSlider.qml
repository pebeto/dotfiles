import QtQuick
import qs

// A volume track with its knob: drag or click to set, scroll to step.
Item {
    id: slider

    property real value: NaN
    property bool muted: false
    readonly property real shown: isNaN(value) ? 0 : Math.max(0, Math.min(1, value))

    signal moved(real value)
    signal stepped(int steps)

    height: Math.round(Theme.em * 1.2)

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Math.max(3, Math.round(Theme.em * 0.2))
        radius: height / 2
        color: Theme.rule
        opacity: 0.5
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * slider.shown
        height: Math.max(3, Math.round(Theme.em * 0.2))
        radius: height / 2
        color: slider.muted ? Theme.inkDim : Theme.accent
    }

    Rectangle {
        x: parent.width * slider.shown - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(Theme.em * 0.8)
        height: width
        radius: width / 2
        color: Theme.paper
        border.width: 1
        border.color: Theme.ink
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: e => slider.moved(Math.max(0, Math.min(1, e.x / width)))
        onPositionChanged: e => {
            if (pressed)
                slider.moved(Math.max(0, Math.min(1, e.x / width)));
        }
        onWheel: e => slider.stepped(e.angleDelta.y > 0 ? 1 : -1)
    }
}
