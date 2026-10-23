pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The default output and the list of outputs to switch between, plus each
// app that is playing sound, with its own volume. Volume is Pipewire's 0..1
// scale, the same one `wpctl get-volume` prints.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? NaN
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    // The default microphone, for the mic-mute key's on-screen readout.
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source?.audio?.muted ?? false
    // Apps playing sound: their output streams.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.type === PwNodeType.AudioOutStream)

    function appName(node) {
        const p = node.properties;
        return p["application.name"] || node.description || node.name;
    }

    function appIcon(node) {
        const p = node.properties;
        return Quickshell.iconPath(p["application.icon-name"] || (p["application.name"] ?? "").toLowerCase(), "audio-x-generic");
    }

    // Names for the outputs whose own descriptions are unhelpful.
    readonly property var names: ({
        "alsa_output.usb-Logitech_PRO_X_Wireless_Gaming_Headset-00.analog-stereo": "PRO X headset",
        "alsa_output.pci-0000_01_00.1.hdmi-stereo": "Samsung screen (HDMI)"
    })

    function label(node) {
        if (!node)
            return "(no output)";
        return names[node.name] ?? (node.nickname || node.description || node.name);
    }

    function step(steps) {
        if (!sink?.audio)
            return;
        const v = Math.round((sink.audio.volume + steps * 0.05) * 100) / 100;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function setVolume(v) {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function use(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    // Pipewire only fills in a node's audio properties while something
    // tracks it.
    PwObjectTracker {
        objects: [...root.sinks, ...root.streams, root.source].filter(n => n)
    }
}
