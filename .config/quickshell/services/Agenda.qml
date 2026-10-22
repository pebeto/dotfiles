pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Today's org agenda for the clock panel, read from the cache that the
// agenda-refresh timer keeps (sway/agenda.sh refresh). emacs --batch is too
// slow to start on demand, so this only ever reads the cache.
Singleton {
    id: root

    readonly property string cache: Quickshell.env("XDG_RUNTIME_DIR") + "/agenda/today.txt"
    // [{ category, items: [{ time, text }] }], in the agenda's own order.
    property var groups: []
    // Any line that isn't an entry, such as "(no org dir at ...)".
    property string note: ""

    function parse(text) {
        const groups = [];
        const notes = [];
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            // The first line is the day header, which the panel shows itself.
            if (i === 0 && /^[A-Za-z]/.test(line))
                continue;
            const m = line.match(/^\s+([A-Za-z0-9_-]+):\s+(.*)$/);
            if (!m) {
                if (line.trim())
                    notes.push(line.trim());
                continue;
            }
            // Timed entries read "13:00...... text" or "9:00-10:30 text".
            const t = m[2].match(/^(\d{1,2}:\d{2}(?:-\d{1,2}:\d{2})?)\.*\s*(.*)$/);
            const item = t ? { time: t[1], text: t[2] } : { time: "", text: m[2].trim() };
            const last = groups[groups.length - 1];
            if (last && last.category === m[1])
                last.items.push(item);
            else
                groups.push({ category: m[1], items: [item] });
        }
        root.groups = groups;
        root.note = notes.join("\n");
    }

    FileView {
        id: file
        path: root.cache
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parse(text())
        // No cache yet (the timer hasn't run since boot): build it once.
        onLoadFailed: refresh.running = true
    }

    Process {
        id: refresh
        command: [Quickshell.env("HOME") + "/.config/sway/agenda.sh", "refresh"]
        onExited: file.reload()
    }
}
