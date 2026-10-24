pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The default output and the list of outputs to switch between, each app
// that is playing sound, with its own volume and output, and the
// microphones. Volume is Pipewire's 0..1 scale, the same one `wpctl
// get-volume` prints.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? NaN
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    // The default microphone and the ones to switch between.
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? NaN
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && n.type === PwNodeType.AudioSource)
    // Apps playing sound: their output streams.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.type === PwNodeType.AudioOutStream)
    // The output each stream plays into, by stream id. Quickshell counts a
    // playback stream as a sink, so a link tracker on the stream sees
    // nothing; one on each output lists the streams feeding it.
    readonly property var routes: {
        const map = {};
        for (let i = 0; i < sinkLinks.count; i++) {
            const tracker = sinkLinks.objectAt(i);
            for (const g of tracker?.linkGroups ?? [])
                if (g.source)
                    map[g.source.id] = tracker.node;
        }
        return map;
    }

    function targetOf(stream) {
        return routes[stream?.id] ?? null;
    }

    function appName(node) {
        const p = node.properties;
        return p["application.name"] || node.description || node.name;
    }

    function appIcon(node) {
        const p = node.properties;
        return Quickshell.iconPath(p["application.icon-name"] || (p["application.name"] ?? "").toLowerCase(), "audio-x-generic");
    }

    // Names for the devices whose own descriptions are unhelpful.
    readonly property var names: ({
        "alsa_output.usb-Logitech_PRO_X_Wireless_Gaming_Headset-00.analog-stereo": "PRO X headset",
        "alsa_output.pci-0000_01_00.1.hdmi-stereo": "Samsung screen (HDMI)",
        "alsa_input.usb-Logitech_PRO_X_Wireless_Gaming_Headset-00.mono-fallback": "PRO X headset",
        "alsa_input.usb-Qigan_Tech_Inc._JXL333_20080411-02.mono-fallback": "Webcam"
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

    function useSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function setMicVolume(v) {
        if (source?.audio)
            source.audio.volume = Math.max(0, Math.min(1, v));
    }

    // Sends an app's stream to another output, or back to the default one
    // with null. WirePlumber follows the stream's target.object for as long
    // as that stream plays; a new stream from the app starts on the default.
    function moveStream(stream, sink) {
        Quickshell.execDetached(sink ? ["pw-metadata", String(stream.id), "target.object", sink.name] : ["pw-metadata", "-d", String(stream.id), "target.object"]);
    }

    function toggleMic() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    function use(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    Instantiator {
        id: sinkLinks
        model: root.sinks

        PwNodeLinkTracker {
            required property var modelData
            node: modelData
        }
    }

    // Pipewire only fills in a node's audio properties while something
    // tracks it.
    PwObjectTracker {
        objects: [...root.sinks, ...root.streams, ...root.sources].filter(n => n)
    }
}
