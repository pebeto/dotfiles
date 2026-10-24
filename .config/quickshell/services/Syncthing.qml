pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Overall Syncthing completion and the devices connected right now, from its
// REST API, read when the Control Center opens. The API key comes out of
// Syncthing's own config.xml.
Singleton {
    id: root

    // "offline", "synced" or "syncing"
    property string state: "offline"
    property int percent: 0
    // Names of the other devices connected now.
    property var connected: []
    property string apiKey: ""

    // Calls back with the parsed reply, or null.
    function get(path, callback) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let data = null;
            try {
                data = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
            } catch (e) {}
            callback(data);
        };
        xhr.open("GET", "http://127.0.0.1:8384" + path);
        xhr.setRequestHeader("X-API-Key", apiKey);
        xhr.timeout = 1000;
        xhr.send();
    }

    function update() {
        if (!apiKey) {
            state = "offline";
            return;
        }
        get("/rest/db/completion", data => {
            const completion = data?.completion;
            if (typeof completion !== "number") {
                root.state = "offline";
                root.connected = [];
                return;
            }
            root.percent = Math.floor(completion);
            root.state = completion >= 100 ? "synced" : "syncing";
        });
        // Connections list only the other devices; the config names them.
        get("/rest/system/connections", connections => {
            get("/rest/config/devices", devices => {
                const on = Object.entries(connections?.connections ?? {}).filter(([, c]) => c.connected).map(([id]) => id);
                root.connected = (devices ?? []).filter(d => on.includes(d.deviceID)).map(d => d.name);
            });
        });
    }

    // Syncthing keeps its config under ~/.local/state since 1.27 and under
    // ~/.config before that, so look in the second place if the first fails.
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/syncthing/config.xml"
        printErrors: false
        onLoaded: root.apiKey = text().match(/<apikey>([^<]+)<\/apikey>/)?.[1] ?? ""
        onLoadFailed: {
            if (!path.includes("/.config/"))
                path = Quickshell.env("HOME") + "/.config/syncthing/config.xml";
        }
    }
}
