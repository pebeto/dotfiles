import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// What's playing, with previous, play/pause and next. It shows the player
// that's playing, or else the first one with a track loaded. playerctld,
// the proxy the media keys talk to, mirrors another player, so it's
// skipped. Clicking the title brings the player's window up.
Item {
    id: root

    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    readonly property var player: players.find(p => p.isPlaying) ?? players.find(p => p.trackTitle) ?? null
    readonly property int art: Math.round(Theme.em * 3.4)

    implicitHeight: art

    ClippingRectangle {
        id: cover

        width: root.art
        height: root.art
        radius: Math.round(Theme.radius * 0.6)
        color: Theme.paperHover

        Glyph {
            anchors.centerIn: parent
            visible: image.status !== Image.Ready
            text: Theme.icons.music
            color: Theme.inkDim
            font.pixelSize: Math.round(Theme.em * 1.6)
        }
        Image {
            id: image
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            sourceSize.width: root.art * 2
            sourceSize.height: root.art * 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column {
        anchors.left: cover.right
        anchors.leftMargin: Theme.gap
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Ink {
            width: parent.width
            text: root.player?.trackTitle || root.player?.identity || ""
            font.bold: true
            elide: Text.ElideRight

            MouseArea {
                anchors.fill: parent
                enabled: root.player?.canRaise ?? false
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.player.raise();
                    Panels.close();
                }
            }
        }
        Ink {
            width: parent.width
            visible: text !== ""
            text: [root.player?.trackArtist, root.player?.trackAlbum].filter(s => s).join(" · ")
            color: Theme.inkDim
            font.pixelSize: Theme.small
            elide: Text.ElideRight
        }
        Row {
            spacing: Theme.gap

            Control {
                text: Theme.icons.previous
                enabled: root.player?.canGoPrevious ?? false
                onActivated: root.player.previous()
            }
            Control {
                text: root.player?.isPlaying ? Theme.icons.pause : Theme.icons.play
                enabled: root.player?.canTogglePlaying ?? false
                onActivated: root.player.togglePlaying()
            }
            Control {
                text: Theme.icons.next
                enabled: root.player?.canGoNext ?? false
                onActivated: root.player.next()
            }
        }
    }

    component Control: Glyph {
        id: control

        signal activated

        color: enabled ? Theme.ink : Theme.inkDim
        font.pixelSize: Math.round(Theme.em * 1.3)

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: control.activated()
        }
    }
}
