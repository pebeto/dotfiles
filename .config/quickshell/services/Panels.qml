pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which panel is open ("clock", "control", "wifi", "bluetooth", "tray",
// "llm", "launcher", "clipboard", "session" or ""), and on which output. One
// at a time, like menus.
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
            root.toggle(name, Sway.focusedOutput);
        }
        function close(): void {
            root.close();
        }
    }
}
