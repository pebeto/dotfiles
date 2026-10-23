import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// The readout at the bottom of the focused screen when a key changes the
// volume, the microphone or the brightness. The sway bindings call
// `qs ipc call osd volume` (or `mic`) after changing the value. Brightness
// has no binding, since the T470's firmware handles those keys, so any
// change of System.brightness shows it instead.
Scope {
    id: root

    // "volume", "mic", "brightness", or "" while hidden.
    property string kind: ""
    // Up while it should show. It fades in and out rather than popping, and
    // keeps the last kind while fading so its contents don't change.
    property bool up: false
    // NaN until the first reading, which is the shell starting, not a change.
    property real lastBrightness: NaN

    readonly property real level: kind === "volume" ? Audio.volume : kind === "brightness" ? System.brightness / 100 : NaN
    readonly property bool off: kind === "volume" ? Audio.muted : kind === "mic" ? Audio.micMuted : false

    function show(k) {
        kind = k;
        up = true;
        hideTimer.restart();
    }

    function icon() {
        if (kind === "mic")
            return Audio.micMuted ? Theme.icons.micOff : Theme.icons.mic;
        if (kind === "brightness")
            return Theme.icons.brightness;
        if (Audio.muted)
            return Theme.icons.volOff;
        return Audio.volume >= 0.66 ? Theme.icons.volHigh : Audio.volume >= 0.33 ? Theme.icons.volMid : Theme.icons.volLow;
    }

    function label() {
        if (kind === "mic")
            return Audio.micMuted ? "Microphone off" : "Microphone on";
        if (kind === "volume" && Audio.muted)
            return "muted";
        return isNaN(level) ? "?" : Math.round(level * 100) + "%";
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.up = false
    }

    Connections {
        target: System

        function onBrightnessChanged() {
            if (!isNaN(root.lastBrightness) && !isNaN(System.brightness) && System.brightness !== root.lastBrightness)
                root.show("brightness");
            root.lastBrightness = System.brightness;
        }
    }

    IpcHandler {
        target: "osd"

        function volume(): void {
            root.show("volume");
        }
        function mic(): void {
            root.show("mic");
        }
    }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.up || card.opacity > 0
        anchors.bottom: true
        margins.bottom: Math.round(Theme.em * 5)
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"
        color: "transparent"
        implicitWidth: card.width
        implicitHeight: card.height
        // Clicks go through to whatever is underneath.
        mask: Region {}

        Rectangle {
            id: card

            width: Math.round(Theme.em * 15)
            height: Math.round(Theme.em * 2.8)
            radius: Theme.radius
            color: Theme.paperGlass
            border.width: 1
            border.color: Theme.rule
            opacity: root.up ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.InOutQuad
                }
            }

            Glyph {
                id: glyph
                x: Math.round(Theme.gap * 1.5)
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon()
                color: root.off ? Theme.critical : Theme.ink
                font.pixelSize: Math.round(Theme.em * 1.4)
            }

            Ink {
                id: pct
                anchors.right: parent.right
                anchors.rightMargin: Math.round(Theme.gap * 1.5)
                anchors.verticalCenter: parent.verticalCenter
                visible: root.kind !== "mic"
                width: Math.round(Theme.em * 3)
                horizontalAlignment: Text.AlignRight
                text: root.label()
                color: root.off ? Theme.inkDim : Theme.ink
            }

            // The microphone is on or off, so it gets words instead of a bar.
            Ink {
                anchors.left: glyph.right
                anchors.leftMargin: Theme.gap
                anchors.verticalCenter: parent.verticalCenter
                visible: root.kind === "mic"
                text: root.label()
                color: root.off ? Theme.critical : Theme.ink
            }

            Item {
                anchors.left: glyph.right
                anchors.leftMargin: Theme.gap
                anchors.right: pct.left
                anchors.rightMargin: Theme.gap
                anchors.verticalCenter: parent.verticalCenter
                visible: root.kind !== "mic"
                height: Math.max(4, Math.round(Theme.em * 0.3))

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Theme.rule
                    opacity: 0.5
                }
                Rectangle {
                    width: parent.width * (isNaN(root.level) ? 0 : Math.min(1, root.level))
                    height: parent.height
                    radius: height / 2
                    color: root.off ? Theme.inkDim : Theme.accent
                }
            }
        }
    }
}
