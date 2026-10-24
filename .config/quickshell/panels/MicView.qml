import QtQuick
import qs
import qs.components
import qs.services

// The microphones to choose from, when there's more than one (a webcam
// plugged in beside the headset), and the default one's level. A click on
// its icon mutes it.
Column {
    id: root

    spacing: 2

    Repeater {
        model: Audio.sources.length > 1 ? Audio.sources : []

        DeviceRow {
            required property var modelData

            width: root.width
            icon: Theme.icons.mic
            label: Audio.label(modelData)
            current: modelData === Audio.source
            onClicked: Audio.useSource(modelData)
        }
    }

    Item {
        width: root.width
        height: Math.round(Theme.em * 2)

        Glyph {
            id: micGlyph
            x: Math.round(Theme.gap * 0.6)
            anchors.verticalCenter: parent.verticalCenter
            text: Audio.micMuted ? Theme.icons.micOff : Theme.icons.mic
            color: Audio.micMuted ? Theme.critical : Theme.ink

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleMic()
            }
        }

        Ink {
            id: pct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(Theme.em * 3)
            horizontalAlignment: Text.AlignRight
            text: !Audio.source ? "none" : isNaN(Audio.micVolume) ? "?" : Math.round(Audio.micVolume * 100) + "%"
            color: Audio.micMuted ? Theme.inkDim : Theme.ink
        }

        VolumeSlider {
            anchors.left: micGlyph.right
            anchors.leftMargin: Theme.gap
            anchors.right: pct.left
            anchors.rightMargin: Theme.gap
            anchors.verticalCenter: parent.verticalCenter
            value: Audio.micVolume
            muted: Audio.micMuted
            onMoved: v => Audio.setMicVolume(v)
            onStepped: steps => Audio.setMicVolume(Math.round((Audio.micVolume + steps * 0.05) * 100) / 100)
        }
    }
}
