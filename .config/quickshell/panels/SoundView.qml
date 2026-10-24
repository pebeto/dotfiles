import QtQuick
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// The outputs to choose from, with the current one checked, a volume slider
// for it, and one for each app playing sound. A click on an app's icon
// mutes it, and on its name lists the outputs to send that app to.
Column {
    id: root

    // The app whose outputs are listed, or null.
    property var choosing: null

    function iconFor(node) {
        const name = node?.name.toLowerCase() ?? "";
        if (name.includes("hdmi") || name.includes("displayport"))
            return Theme.icons.monitor;
        if (name.includes("usb") || name.includes("headset") || name.includes("bluez"))
            return Theme.icons.headphones;
        return Theme.icons.speaker;
    }

    spacing: 2

    Repeater {
        model: Audio.sinks

        DeviceRow {
            required property var modelData

            width: root.width
            icon: root.iconFor(modelData)
            label: Audio.label(modelData)
            current: modelData === Audio.sink
            onClicked: Audio.use(modelData)
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

    Repeater {
        model: Audio.streams

        Column {
            id: app

            required property var modelData
            readonly property real volume: modelData.audio?.volume ?? NaN
            readonly property bool muted: modelData.audio?.muted ?? false
            // The output it's linked to now.
            readonly property var target: Audio.targetOf(modelData)
            readonly property bool elsewhere: target !== null && target !== Audio.sink

            width: root.width

            Item {
                width: parent.width
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
                    width: Math.round(Theme.em * 6) - (outputGlyph.visible ? outputGlyph.width + Theme.gap : 0)
                    text: Audio.appName(app.modelData)
                    font.pixelSize: Theme.small
                    font.underline: nameMouse.containsMouse
                    color: app.muted ? Theme.inkDim : Theme.ink
                    elide: Text.ElideRight

                    MouseArea {
                        id: nameMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.choosing = root.choosing === app.modelData ? null : app.modelData
                    }
                }
                // Sent somewhere other than the default output.
                Glyph {
                    id: outputGlyph
                    anchors.left: appName.right
                    anchors.leftMargin: Theme.gap
                    anchors.verticalCenter: parent.verticalCenter
                    visible: app.elsewhere
                    text: root.iconFor(app.target)
                    color: Theme.inkDim
                    font.pixelSize: Theme.small
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
                    anchors.left: appIcon.right
                    anchors.leftMargin: Math.round(Theme.em * 6) + Theme.gap * 2
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

            // Where to send this app: the default output, which follows
            // whatever is checked above, or one in particular.
            Column {
                visible: root.choosing === app.modelData
                x: Math.round(Theme.em * 1.6)
                width: parent.width - x
                spacing: 2

                DeviceRow {
                    width: parent.width
                    icon: root.iconFor(Audio.sink)
                    label: "Default · " + Audio.label(Audio.sink)
                    current: !app.elsewhere
                    onClicked: {
                        Audio.moveStream(app.modelData, null);
                        root.choosing = null;
                    }
                }
                Repeater {
                    model: Audio.sinks

                    DeviceRow {
                        required property var modelData

                        width: parent.width
                        icon: root.iconFor(modelData)
                        label: Audio.label(modelData)
                        current: app.elsewhere && modelData === app.target
                        onClicked: {
                            Audio.moveStream(app.modelData, modelData);
                            root.choosing = null;
                        }
                    }
                }
            }
        }
    }
}
