pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The applications the launcher offers, ranked by how well they match the
// query and by how often each was launched. The counts live in fuzzel's
// cache (~/.cache/fuzzel, "desktop-id|count" lines), so fuzzel, which sway
// falls back to when the shell isn't running, ranks them the same way.
Singleton {
    id: root

    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    property var counts: ({})

    function uses(entry) {
        return counts[entry.id + ".desktop"] ?? 0;
    }

    function span(from, length) {
        return Array.from({ length: length }, (_, i) => from + i);
    }

    // How well `query` (lowercase) matches the name `text`: a prefix beats
    // the start of a later word, which beats any other substring, which
    // beats the letters in order with gaps between them (fuzzel's fuzzy
    // mode). Null for no match, else the score and the positions of the
    // matched letters.
    function match(text, query) {
        const t = text.toLowerCase();
        const at = t.indexOf(query);
        if (at === 0)
            return { score: 400, hits: span(0, query.length) };
        if (at > 0)
            return { score: (/[\s\-_.]/.test(t[at - 1]) ? 300 : 200) - at, hits: span(at, query.length) };
        const hits = [];
        for (let k = 0; k < t.length && hits.length < query.length; k++) {
            if (t[k] === query[hits.length])
                hits.push(k);
        }
        if (hits.length < query.length)
            return null;
        const gaps = hits[hits.length - 1] - hits[0] + 1 - query.length;
        return { score: Math.max(1, 100 - gaps), hits: hits };
    }

    // The same for the other fields, but only where a word starts there.
    function wordMatch(text, query) {
        const t = text.toLowerCase();
        for (let at = t.indexOf(query); at >= 0; at = t.indexOf(query, at + 1)) {
            if (at === 0 || /[\s\-_.]/.test(t[at - 1]))
                return { score: at === 0 ? 400 : 300 - at, hits: span(at, query.length) };
        }
        return null;
    }

    // [{ entry, hits }], best first: hits are the matched letters of the
    // name. With an empty query, every app, most used first. The name
    // matches fuzzily; the generic name, the desktop id and the keywords
    // only where one of their words starts, and for less than a word of the
    // name does (Settings in the name beats a "settings" keyword), since
    // "ste" inside "system" or scattered letters there are noise. Launch
    // counts break near-ties.
    function search(query) {
        const q = query.trim().toLowerCase();
        const found = [];
        for (const e of apps) {
            const n = uses(e);
            if (q === "") {
                found.push({ entry: e, hits: [], rank: n });
                continue;
            }
            const onName = match(e.name, q);
            let best = onName ? onName.score : -1;
            for (const field of [e.genericName, e.id, ...e.keywords]) {
                const m = field ? wordMatch(field, q) : null;
                if (m)
                    best = Math.max(best, m.score * 0.6);
            }
            if (best < 0)
                continue;
            found.push({ entry: e, hits: onName ? onName.hits : [], rank: best + Math.min(40, 10 * Math.log2(1 + n)) });
        }
        found.sort((a, b) => b.rank - a.rank || a.entry.name.localeCompare(b.entry.name));
        return found;
    }

    // Terminal apps (btop, Neovim) open in foot, as fuzzel's terminal=foot
    // did.
    function launch(entry) {
        if (entry.runInTerminal)
            Quickshell.execDetached(["foot", "-e", ...entry.command]);
        else
            entry.execute();
        const key = entry.id + ".desktop";
        const next = Object.assign({}, counts);
        next[key] = (next[key] ?? 0) + 1;
        counts = next;
        cache.setText(Object.keys(next).sort().map(k => k + "|" + next[k]).join("\n") + "\n");
    }

    FileView {
        id: cache

        path: Quickshell.env("HOME") + "/.cache/fuzzel"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const c = {};
            for (const line of text().split("\n")) {
                const bar = line.lastIndexOf("|");
                if (bar > 0)
                    c[line.slice(0, bar)] = parseInt(line.slice(bar + 1)) || 0;
            }
            root.counts = c;
        }
    }
}
