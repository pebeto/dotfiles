pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Overall Syncthing completion from its REST API, read when the clock panel
// opens. The API key comes out of Syncthing's own config.xml.
Singleton {
    id: root

    // "offline", "synced" or "syncing"
    property string state: "offline"
    property int percent: 0
    property string apiKey: ""

    function update() {
        if (!apiKey) {
            state = "offline";
            return;
        }
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let completion = NaN;
            try {
                completion = JSON.parse(xhr.responseText).completion;
            } catch (e) {}
            if (xhr.status !== 200 || isNaN(completion)) {
                root.state = "offline";
                return;
            }
            root.percent = Math.floor(completion);
            root.state = completion >= 100 ? "synced" : "syncing";
        };
        xhr.open("GET", "http://127.0.0.1:8384/rest/db/completion");
        xhr.setRequestHeader("X-API-Key", apiKey);
        xhr.timeout = 1000;
        xhr.send();
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
