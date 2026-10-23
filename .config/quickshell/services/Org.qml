pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Quick capture for the launcher's "+": a TODO appended to refile.org, the
// notes file nvim-orgmode refiles from, in the shape of its own task
// template (the heading, then the day it was captured).
Singleton {
    id: root

    readonly property string file: Quickshell.env("HOME") + "/Sync/orgfiles/refile.org"

    function capture(task) {
        const d = new Date();
        const pad = n => String(n).padStart(2, "0");
        const day = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()];
        const stamp = `[${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${day}]`;
        // A newline first if the file doesn't end with one.
        writer.command = ["sh", "-c", "[ -s \"$1\" ] && [ -n \"$(tail -c1 \"$1\")\" ] && echo >> \"$1\"; printf '%s\\n' \"$2\" >> \"$1\"", "sh", file, "* TODO " + task + "\n  " + stamp];
        writer.task = task;
        writer.running = true;
    }

    Process {
        id: writer

        property string task: ""

        onExited: code => Quickshell.execDetached(code === 0 ? ["notify-send", "-a", "Org", "Added to refile.org", task] : ["notify-send", "-a", "Org", "-u", "critical", "Couldn't write refile.org", task])
    }
}
