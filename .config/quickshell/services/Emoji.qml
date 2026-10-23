pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Emoji for the launcher's ":" search, from Unicode's own list (the
// unicode-emoji package). Only the fully-qualified forms, and no skin-tone
// variants, so each emoji appears once. It loads the first time it's
// searched.
Singleton {
    id: root

    // [{ char, name }]
    property var list: []
    readonly property bool loaded: list.length > 0

    // Emoji whose name has a word starting with `query`, earliest word
    // first, with the matched span of the name.
    function search(query) {
        const q = query.trim().toLowerCase();
        if (q === "")
            return [];
        const found = [];
        for (const e of list) {
            const n = e.name;
            for (let at = n.indexOf(q); at >= 0; at = n.indexOf(q, at + 1)) {
                if (at === 0 || n[at - 1] === " " || n[at - 1] === "-") {
                    found.push({ char: e.char, name: n, at: at, hits: Array.from({ length: q.length }, (_, i) => at + i) });
                    break;
                }
            }
        }
        found.sort((a, b) => a.at - b.at || a.name.length - b.name.length);
        return found;
    }

    FileView {
        path: "/usr/share/unicode/emoji/emoji-test.txt"
        onLoaded: {
            const out = [];
            // 1F600  ; fully-qualified  # 😀 E1.0 grinning face
            for (const line of text().split("\n")) {
                if (!line.includes("; fully-qualified"))
                    continue;
                const m = /#\s*(\S+)\s+E\d+\.\d+\s+(.+)$/.exec(line);
                if (m && !m[2].includes("skin tone"))
                    out.push({ char: m[1], name: m[2].toLowerCase() });
            }
            root.list = out;
        }
    }
}
