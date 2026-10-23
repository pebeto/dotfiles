pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The clipboard history cliphist keeps (its wl-paste watcher starts from
// sway/config), for the picker's clipboard mode. It's read fresh each time
// the picker opens, and picking an entry decodes it back onto the
// clipboard. Images are also decoded into $XDG_RUNTIME_DIR for the picker's
// thumbnails, once each.
Singleton {
    id: root

    // [{ line, text, image, detail, thumb }], newest first. `line` is
    // cliphist's own "id<TAB>preview" line, which `cliphist decode` takes
    // back; `thumb` is an image's decoded file.
    property var entries: []
    readonly property string thumbDir: Quickshell.env("XDG_RUNTIME_DIR") + "/cliphist-thumbs"
    // Off while a fresh list's images are being decoded.
    property bool thumbsReady: false

    function refresh() {
        thumbsReady = false;
        lister.running = true;
    }

    // cliphist's preview of an image: "[[ binary data 39 KiB png 1920x1080 ]]".
    function entry(line) {
        const id = line.slice(0, line.indexOf("\t"));
        const preview = line.slice(line.indexOf("\t") + 1);
        const m = /^\[\[ binary data (.+) (\w+) (\d+)x(\d+) \]\]$/.exec(preview);
        if (!m)
            return { line: line, text: preview, image: preview.startsWith("[[ binary data"), detail: "", thumb: "" };
        return { line: line, text: "Image " + m[3] + "×" + m[4], image: true, detail: m[2] + ", " + m[1], thumb: thumbDir + "/" + id + "." + m[2] };
    }

    // The entries containing `query`, newest first, with the matched span.
    // Plain substrings: letters scattered across long clipboard text match
    // almost anything.
    function search(query) {
        const q = query.trim().toLowerCase();
        const found = [];
        for (const e of entries) {
            const at = q === "" ? 0 : e.text.toLowerCase().indexOf(q);
            if (at < 0)
                continue;
            found.push({ entry: e, hits: q === "" ? [] : Array.from({ length: q.length }, (_, i) => at + i) });
        }
        return found;
    }

    function restore(entry) {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", entry.line]);
    }

    Process {
        id: lister

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.includes("\t")).map(l => root.entry(l));
                const images = root.entries.filter(e => e.thumb).map(e => e.thumb.slice(root.thumbDir.length + 1) + "=" + e.line);
                thumbs.command = [Quickshell.shellPath("scripts/clip-thumbs.sh"), root.thumbDir, ...images];
                thumbs.running = true;
            }
        }
    }

    Process {
        id: thumbs
        onExited: root.thumbsReady = true
    }
}
