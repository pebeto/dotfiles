import QtQuick
import qs
import qs.components
import qs.services

// The outputs to choose from, with the current one checked, and a volume
// slider for it.
Column {
    id: root

    function iconFor(node) {
        const name = node.name.toLowerCase();
        if (name.includes("hdmi") || name.includes("displayport"))
            return Theme.icons.monitor;
        if (name.includes("usb") || name.includes("headset") || name.includes("bluez"))
            return Theme.icons.headphones;
        return Theme.icons.speaker;
    }

    spacing: 2

    Repeater {
        model: Audio.sinks

        Rectangle {
            id: row

            required property var modelData
            readonly property bool current: modelData === Audio.sink

            width: root.width
            height: Math.round(Theme.em * 1.7)
            radius: Math.round(Theme.radius * 0.6)
            color: current ? Theme.highlight : rowMouse.containsMouse ? Theme.paperHover : "transparent"

            Row {
                x: Math.round(Theme.gap * 0.6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.gap

                Glyph {
                    text: root.iconFor(row.modelData)
                    color: Theme.ink
                }
                Ink {
                    text: Audio.label(row.modelData)
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
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.use(row.modelData)
            }
        }
    }

    Item {
        width: root.width
        height: Math.round(Theme.em * 2)

        Glyph {
            id: muteGlyph
            x: Math.round(Theme.gap * 0.6)
            anchors.verticalCenter: parent.verticalCenter
            text: Audio.muted ? Theme.icons.volOff : Theme.icons.volHigh
            color: Audio.muted ? Theme.critical : Theme.ink

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleMute()
            }
        }

        Ink {
            id: pct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(Theme.em * 3)
            horizontalAlignment: Text.AlignRight
            text: isNaN(Audio.volume) ? "?" : Math.round(Audio.volume * 100) + "%"
            color: Audio.muted ? Theme.inkDim : Theme.ink
        }

        Item {
            id: slider

            anchors.left: muteGlyph.right
            anchors.leftMargin: Theme.gap
            anchors.right: pct.left
            anchors.rightMargin: Theme.gap
            anchors.verticalCenter: parent.verticalCenter
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
                width: parent.width * (isNaN(Audio.volume) ? 0 : Audio.volume)
                height: Math.max(3, Math.round(Theme.em * 0.2))
                radius: height / 2
                color: Audio.muted ? Theme.inkDim : Theme.accent
            }

            Rectangle {
                x: parent.width * (isNaN(Audio.volume) ? 0 : Audio.volume) - width / 2
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
                onPressed: e => Audio.setVolume(e.x / width)
                onPositionChanged: e => {
                    if (pressed)
                        Audio.setVolume(e.x / width);
                }
                onWheel: e => Audio.step(e.angleDelta.y > 0 ? 1 : -1)
            }
        }
    }
}
