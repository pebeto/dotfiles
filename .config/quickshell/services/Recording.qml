pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether sway/screen-record.sh is recording and for how long, for the bar's
// red dot. The script reports starting and stopping over IPC. While it
// records, wf-recorder's own run time is read every few seconds, which keeps
// the clock right and notices a recorder that ended by itself; it's also read
// once at startup, in case the shell restarted mid-recording.
Singleton {
    id: root

    property bool active: false
    property int elapsed: 0

    // The script stops a running recording when started again.
    function toggle() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/sway/screen-record.sh"]);
    }

    Process {
        id: check

        running: true
        command: ["sh", "-c", "p=$(pgrep -x -n wf-recorder) && ps -o etimes= -p \"$p\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const seconds = parseInt(text.trim());
                root.active = !isNaN(seconds);
                if (root.active)
                    root.elapsed = seconds;
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: {
            root.elapsed += 1;
            if (root.elapsed % 3 === 0)
                check.running = true;
        }
    }

    IpcHandler {
        target: "recording"

        function started(): void {
            root.elapsed = 0;
            root.active = true;
        }
        function stopped(): void {
            root.active = false;
        }
    }
}
