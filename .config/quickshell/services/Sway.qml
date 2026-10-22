pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// What the bar needs from sway beyond Quickshell.I3's workspace list: the
// active keyboard layout and the binding mode, both kept current from IPC
// events.
Singleton {
    id: root

    // Short names, in the order of `xkb_layout us,latam` in sway/config.
    readonly property var layoutNames: ["us", "latam"]
    property int layoutIndex: -1
    readonly property string layout: layoutNames[layoutIndex] ?? "?"
    property string mode: "default"

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
