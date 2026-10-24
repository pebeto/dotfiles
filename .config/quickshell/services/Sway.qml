pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// What the shell needs from sway beyond Quickshell.I3's workspace list: the
// active keyboard layout, the binding mode, the focused output and
// workspace, and whether a fullscreen window covers that output, all kept
// current from IPC events.
//
// The focus comes from sway's own events rather than I3.focusedMonitor and
// I3.focusedWorkspace: Quickshell keeps those pointing at an output it has
// deleted after the output disconnects (the monitor sleeping), and reading
// them then crashed the shell.
Singleton {
    id: root

    // Short names, in the order of `xkb_layout us,latam` in sway/config.
    readonly property var layoutNames: ["us", "latam"]
    property int layoutIndex: -1
    readonly property string layout: layoutNames[layoutIndex] ?? "?"
    property string mode: "default"
    property string focusedOutput: ""
    property string focusedWorkspace: ""
    // A fullscreen window showing on the focused output (a game, a video).
    property bool fullscreen: false

    function hasFullscreen(node) {
        if (node.fullscreen_mode > 0 && node.visible)
            return true;
        return [...(node.nodes ?? []), ...(node.floating_nodes ?? [])].some(n => hasFullscreen(n));
    }

    onFocusedOutputChanged: treeTimer.restart()

    function nextLayout() {
        I3.dispatch("input type:keyboard xkb_switch_layout next");
    }

    Process {
        running: true
        command: ["swaymsg", "-t", "get_inputs", "-r"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const input of JSON.parse(text)) {
                    if (input.type === "keyboard" && input.xkb_active_layout_index !== undefined) {
                        root.layoutIndex = input.xkb_active_layout_index;
                        break;
                    }
                }
            }
        }
    }

    Process {
        id: focus

        running: true
        command: ["swaymsg", "-t", "get_workspaces", "-r"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const ws = JSON.parse(text).find(w => w.focused);
                    root.focusedOutput = ws?.output ?? "";
                    root.focusedWorkspace = ws?.name ?? "";
                } catch (e) {}
            }
        }
    }

    Process {
        id: tree

        command: ["swaymsg", "-t", "get_tree", "-r"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const output = JSON.parse(text).nodes?.find(o => o.name === root.focusedOutput);
                    root.fullscreen = !!output && root.hasFullscreen(output);
                } catch (e) {}
            }
        }
    }

    // Window events come in bursts, so the tree is read once they settle.
    Timer {
        id: treeTimer
        interval: 150
        onTriggered: tree.running = true
    }

    // A workspace focus change carries the new workspace and its output;
    // anything else (a workspace created or moved, an output added or gone)
    // asks again. Window events only matter for fullscreen, and title
    // changes, the most frequent, not at all.
    I3IpcListener {
        subscriptions: ["workspace", "output", "window"]
        onIpcEvent: event => {
            const data = JSON.parse(event.data);
            if (data.container !== undefined) {
                if (data.change !== "title" && data.change !== "mark" && data.change !== "urgent")
                    treeTimer.restart();
                return;
            }
            if (data.change === "focus" && data.current?.output) {
                root.focusedOutput = data.current.output;
                root.focusedWorkspace = data.current.name;
            } else {
                focus.running = true;
            }
            treeTimer.restart();
        }
    }

    I3IpcListener {
        subscriptions: ["input", "mode"]
        onIpcEvent: event => {
            const data = JSON.parse(event.data);
            if (data.input !== undefined) {
                if (data.input.type === "keyboard" && data.input.xkb_active_layout_index !== undefined)
                    root.layoutIndex = data.input.xkb_active_layout_index;
            } else if (data.change !== undefined) {
                root.mode = data.change;
            }
        }
    }
}
