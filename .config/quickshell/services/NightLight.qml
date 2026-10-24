pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The night light: gammastep, which each host starts from sway (hosts/*.conf)
// and which pauses and resumes on SIGUSR1. It can't be asked which it's
// doing, so pausing leaves a marker in $XDG_RUNTIME_DIR with gammastep's pid,
// and the marker only counts while that same process runs: a gammastep
// started again begins with the night light on.
Singleton {
    id: root

    readonly property string marker: Quickshell.env("XDG_RUNTIME_DIR") + "/night-light-paused"
    // gammastep is running at all.
    property bool available: false
    property bool on: true

    function toggle() {
        if (!available)
            return;
        on = !on;
        Quickshell.execDetached(["sh", "-c", on ? "rm -f \"$1\"" : "pgrep -x -o gammastep > \"$1\"", "sh", marker]);
        Quickshell.execDetached(["pkill", "-USR1", "-x", "gammastep"]);
    }

    function refresh() {
        check.running = true;
    }

    // "gammastep's pid|the marker's pid"
    Process {
        id: check

        running: true
        command: ["sh", "-c", "printf '%s|%s' \"$(pgrep -x -o gammastep)\" \"$(cat \"$1\" 2>/dev/null)\"", "sh", root.marker]
        stdout: StdioCollector {
            onStreamFinished: {
                const [pid, paused] = text.split("|").map(l => l.trim());
                root.available = pid !== "";
                root.on = !(pid && paused === pid);
            }
        }
    }
}
