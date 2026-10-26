pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The org agenda for the clock panel. Today's is read from the cache that
// the agenda-refresh timer keeps (sway/agenda.sh refresh), so the panel has
// it the moment it opens. Other days come from a whole month that
// `agenda.sh month` renders when the calendar shows it, in about half a
// second.
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.config/sway/agenda.sh"
    readonly property string cache: Quickshell.env("XDG_RUNTIME_DIR") + "/agenda/today.txt"
    // [{ category, items: [{ time, text }] }], in the agenda's own order.
    property var groups: []
    // Any line that isn't an entry, such as "(no org dir at ...)".
    property string note: ""
    // The month last rendered ("2026-10") and its days by date
    // ("2026-10-26"), each { groups, note }.
    property string month: ""
    property var days: ({})
    property bool loading: false

    // One day's lines, after its header.
    function parseDay(lines) {
        const groups = [];
        const notes = [];
        for (const line of lines) {
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
        return { groups: groups, note: notes.join("\n") };
    }

    // Today's cache: the day header, which the panel shows itself, then
    // the entries.
    function parse(text) {
        const lines = text.split("\n");
        if (/^[A-Za-z]/.test(lines[0] ?? ""))
            lines.shift();
        const day = parseDay(lines);
        root.groups = day.groups;
        root.note = day.note;
    }

    // A month: "Sunday      1 November 2026" opens each day.
    function parseMonth(text) {
        const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        const days = {};
        let key = "";
        let lines = [];
        const flush = () => {
            if (key)
                days[key] = parseDay(lines);
        };
        for (const line of text.split("\n")) {
            const h = line.match(/^[A-Z][a-z]+day\s+(\d{1,2}) ([A-Z][a-z]+) (\d{4})/);
            if (h) {
                flush();
                key = h[3] + "-" + String(months.indexOf(h[2]) + 1).padStart(2, "0") + "-" + h[1].padStart(2, "0");
                lines = [];
            } else {
                lines.push(line);
            }
        }
        flush();
        return days;
    }

    // `month` is 0-11, as in Date. A month already rendered since the last
    // invalidate() isn't rendered again.
    function loadMonth(year, month) {
        const want = year + "-" + String(month + 1).padStart(2, "0");
        if (want === root.month || (want === monthProc.want && monthProc.running))
            return;
        monthProc.want = want;
        if (!monthProc.running)
            monthProc.render();
    }

    // The org files may have changed since: render again on the next ask.
    function invalidate() {
        month = "";
    }

    // { groups, note } for a "YYYY-MM-DD", or null while its month loads.
    function day(key) {
        if (month !== key.slice(0, 7))
            return null;
        return days[key] ?? { groups: [], note: "" };
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
        command: [root.script, "refresh"]
        onExited: file.reload()
    }

    // One month at a time; flipping through months while one renders asks
    // again for the last one shown once it's done.
    Process {
        id: monthProc

        property string want: ""
        property string asked: ""

        function render() {
            asked = want;
            command = [root.script, "month", asked];
            root.loading = true;
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                root.days = root.parseMonth(text);
                root.month = monthProc.asked;
            }
        }
        onExited: {
            if (want !== asked)
                render();
            else
                root.loading = false;
        }
    }
}
