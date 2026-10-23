pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// What is using the microphone, the camera or the screen right now, for the
// bar's in-use indicators (macOS's orange and green dots). It reads
// PipeWire's streams: an app recording sound is an audio input stream, one
// watching a camera or a shared screen is a video input stream, and a shared
// screen comes from the screencast portal's own video source. Peak meters,
// like pavucontrol's level bars, are left out.
Singleton {
    id: root

    // Pipewire only gives a node's properties while something tracks it,
    // and has no type for video streams, so this tracks the capture
    // streams, the video sources and the untyped nodes.
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioInStream || n.type === PwNodeType.VideoSource || n.type === PwNodeType.Untracked)

    function kind(n) {
        return n.properties["media.class"] ?? "";
    }

    function app(n) {
        return n.properties["application.name"] || n.description || n.name;
    }

    function unique(names) {
        return [...new Set(names)];
    }

    readonly property var micApps: unique(nodes.filter(n => kind(n) === "Stream/Input/Audio" && n.properties["stream.monitor"] !== "true").map(app))
    readonly property var screenSources: nodes.filter(n => kind(n) === "Video/Source" && /xdpw|portal/i.test(n.name + " " + (n.properties["application.name"] ?? "")))
    readonly property var videoInputs: nodes.filter(n => kind(n) === "Stream/Input/Video")
    readonly property bool screenShared: screenSources.length > 0
    // Each shared screen has one watcher; any video input beyond those is
    // reading a camera.
    readonly property bool cameraUsed: videoInputs.length > screenSources.length
    readonly property bool any: micApps.length > 0 || screenShared || cameraUsed

    PwObjectTracker {
        objects: root.nodes
    }
}
