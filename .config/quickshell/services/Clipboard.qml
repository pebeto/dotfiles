pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The clipboard history cliphist keeps (its wl-paste watcher starts from
// sway/config), for the picker's clipboard mode. It's read fresh each time
// the picker opens, and picking an entry decodes it back onto the
// clipboard.
Singleton {
    id: root

    // [{ line, text, image }], newest first. `line` is cliphist's own
    // "id<TAB>preview" line, which `cliphist decode` takes back.
    property var entries: []

    function refresh() {
        lister.running = true;
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
            onStreamFinished: root.entries = text.split("\n").filter(l => l.includes("\t")).map(l => {
                const preview = l.slice(l.indexOf("\t") + 1);
                return { line: l, text: preview, image: preview.startsWith("[[ binary data") };
            })
        }
    }
}
