import QtQuick
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// The outputs to choose from, with the current one checked, a volume slider
// for it, and one for each app playing sound.
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

        VolumeSlider {
            anchors.left: muteGlyph.right
            anchors.leftMargin: Theme.gap
            anchors.right: pct.left
            anchors.rightMargin: Theme.gap
            anchors.verticalCenter: parent.verticalCenter
            value: Audio.volume
            muted: Audio.muted
            onMoved: v => Audio.setVolume(v)
            onStepped: steps => Audio.step(steps)
        }
    }

    // One row per app playing sound: its icon and name, its own volume,
    // and a click on the icon mutes it.
    Repeater {
        model: Audio.streams

        Item {
            id: app

            required property var modelData
            readonly property real volume: modelData.audio?.volume ?? NaN
            readonly property bool muted: modelData.audio?.muted ?? false

            width: root.width
            height: Math.round(Theme.em * 1.8)

            IconImage {
                id: appIcon
                x: Math.round(Theme.gap * 0.6)
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: Math.round(Theme.em * 1.1)
                source: Audio.appIcon(app.modelData)
                opacity: app.muted ? 0.4 : 1

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (app.modelData.audio)
                            app.modelData.audio.muted = !app.muted;
                    }
                }
            }
            Ink {
                id: appName
                anchors.left: appIcon.right
                anchors.leftMargin: Theme.gap
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(Theme.em * 6)
                text: Audio.appName(app.modelData)
                font.pixelSize: Theme.small
                color: app.muted ? Theme.inkDim : Theme.ink
                elide: Text.ElideRight
            }
            Ink {
                id: appPct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(Theme.em * 3)
                horizontalAlignment: Text.AlignRight
                text: isNaN(app.volume) ? "?" : app.muted ? "muted" : Math.round(app.volume * 100) + "%"
                font.pixelSize: Theme.small
                color: app.muted ? Theme.inkDim : Theme.ink
            }
            VolumeSlider {
                anchors.left: appName.right
                anchors.leftMargin: Theme.gap
                anchors.right: appPct.left
                anchors.rightMargin: Theme.gap
                anchors.verticalCenter: parent.verticalCenter
                value: app.volume
                muted: app.muted
                onMoved: v => {
                    if (app.modelData.audio)
                        app.modelData.audio.volume = v;
                }
                onStepped: steps => {
                    if (app.modelData.audio)
                        app.modelData.audio.volume = Math.max(0, Math.min(1, Math.round((app.volume + steps * 0.05) * 100) / 100));
                }
            }
        }
    }
}
