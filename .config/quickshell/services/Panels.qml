pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// Which panel is open ("clock", "wifi", "bluetooth", "tray", "launcher",
// "clipboard" or ""), and on which output. One at a time, like menus.
Singleton {
    id: root

    property string open: ""
    property string screen: ""

    function toggle(name, screenName) {
        if (open === name) {
            open = "";
            return;
        }
        screen = screenName;
        open = name;
    }

    function close() {
        open = "";
    }

    // For key bindings: `qs ipc call panel toggle bluetooth`.
    IpcHandler {
        target: "panel"

        function toggle(name: string): void {
            root.toggle(name, I3.focusedMonitor?.name ?? "");
        }
        function close(): void {
            root.close();
        }
    }
}
