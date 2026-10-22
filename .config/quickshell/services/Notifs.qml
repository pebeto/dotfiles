pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification server, the popups on screen, a short history for the
// clock panel, and focus mode: do-not-disturb plus a frozen
// swayidle, so the screen neither locks nor blanks while you work.
Singleton {
    id: root

    // Entries, newest first. An entry outlives its Notification, which the
    // sender can close at any time, so the history keeps its own copy.
    property var popups: []
    property var history: []
    readonly property int historyLength: 30

    property bool dnd: false
    property int missed: 0
    readonly property string statePath: Quickshell.env("XDG_RUNTIME_DIR") + "/focus-mode.state"

    // Ten seconds, and critical ones stay until dismissed. A timeout the
    // sender asks for wins.
    readonly property int defaultTimeout: 10000

    // A themed icon by name, or its symbolic variant, or nothing; never the
    // checkerboard Qt draws for a name it can't find.
    function themeIcon(name) {
        if (!name)
            return "";
        if (Quickshell.hasThemeIcon(name))
            return Quickshell.iconPath(name);
        if (Quickshell.hasThemeIcon(name + "-symbolic"))
            return Quickshell.iconPath(name + "-symbolic");
        return "";
    }

    // notify-send -i arrives as an image://icon/ URL, so it goes through the
    // same name lookup; real images (paths, pixel data) are used as they are.
    function iconFor(n) {
        if (n.image.startsWith("image://icon/"))
            return themeIcon(n.image.slice("image://icon/".length));
        if (n.image)
            return n.image;
        if (n.appIcon.startsWith("/") || n.appIcon.startsWith("file:"))
            return n.appIcon;
        return themeIcon(n.appIcon) || themeIcon(DesktopEntries.byId(n.desktopEntry)?.icon ?? "");
    }

    function add(n) {
        n.tracked = true;

        // Stack tags: a new notification with the same tag replaces the old
        // one instead of piling up beside it. Some apps still send dunst's
        // name for the hint, so both are read.
        const tag = n.hints["x-dunst-stack-tag"] ?? n.hints["x-canonical-private-synchronous"] ?? "";
        if (tag) {
            for (const e of [...popups, ...history])
                if (e.tag === tag)
                    forget(e);
        }

        const timeout = n.expireTimeout > 0 ? n.expireTimeout : n.urgency === NotificationUrgency.Critical ? 0 : defaultTimeout;
        const e = entry.createObject(root, {
            n: n,
            app: n.appName,
            summary: n.summary,
            body: n.body,
            icon: iconFor(n),
            urgency: n.urgency,
            time: new Date(),
            tag: tag,
            timeout: timeout,
            remaining: timeout,
            missed: dnd
        });
        n.summaryChanged.connect(() => refresh(e));
        n.bodyChanged.connect(() => refresh(e));
        n.closed.connect(() => popups = popups.filter(p => p !== e));

        history = [e, ...history];
        while (history.length > historyLength)
            drop(history[history.length - 1], "history");

        // After a config reload the server hands back what it still tracks;
        // those were already seen, so they only go to the history.
        if (n.lastGeneration)
            return;
        if (dnd) {
            missed += 1;
            return;
        }
        popups = [e, ...popups];
    }

    // A sender replaced a notification in place (notify-send -r): show it
    // again with a fresh timeout.
    function refresh(e) {
        if (!e.n)
            return;
        e.summary = e.n.summary;
        e.body = e.n.body;
        e.icon = iconFor(e.n);
        e.time = new Date();
        e.remaining = e.timeout;
        if (!dnd && !popups.includes(e))
            popups = [e, ...popups];
    }

    // Takes an entry off one list ("popups" or "history") and frees it once
    // it is on neither.
    function drop(e, list) {
        if (list === "popups")
            popups = popups.filter(p => p !== e);
        else
            history = history.filter(h => h !== e);
        if (!popups.includes(e) && !history.includes(e))
            e.destroy(1000);
    }

    // The popup goes away but stays in the history.
    function dismiss(e) {
        e.n?.dismiss();
        drop(e, "popups");
    }

    function expire(e) {
        e.n?.expire();
        drop(e, "popups");
    }

    // Gone from both the screen and the history.
    function forget(e) {
        e.n?.dismiss();
        drop(e, "popups");
        drop(e, "history");
    }

    function dismissAll() {
        for (const e of popups)
            dismiss(e);
    }

    function clearHistory() {
        for (const e of history)
            forget(e);
        missed = 0;
    }

    // Runs the action, then closes the popup. Middle-click runs "default".
    function invoke(e, identifier) {
        const action = e.n?.actions.find(a => a.identifier === identifier);
        if (action)
            action.invoke();
        dismiss(e);
    }

    function setDnd(on) {
        if (on === dnd)
            return;
        dnd = on;
        Quickshell.execDetached(["pkill", on ? "-STOP" : "-CONT", "swayidle"]);
        if (on) {
            missed = 0;
            Quickshell.execDetached(["touch", statePath]);
            for (const e of popups)
                drop(e, "popups");
            return;
        }
        Quickshell.execDetached(["rm", "-f", statePath]);
        // One summary instead of replaying everything that came in; the
        // notifications themselves are in the history, marked as missed.
        if (missed > 0) {
            const e = entry.createObject(root, {
                app: "Focus",
                summary: "Focus mode off",
                body: `You missed ${missed} notification${missed === 1 ? "" : "s"}`,
                time: new Date(),
                timeout: defaultTimeout,
                remaining: defaultTimeout
            });
            popups = [e, ...popups];
        }
        missed = 0;
    }

    component Entry: QtObject {
        property Notification n
        property string app
        property string summary
        property string body
        property string icon
        property int urgency: NotificationUrgency.Normal
        property date time
        property string tag
        property int timeout
        property int remaining
        property bool hovered
        property bool missed
    }

    Component {
        id: entry
        Entry {}
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => root.add(n)
    }

    // Counts down only while a popup is on screen and not under the pointer.
    Timer {
        interval: 250
        repeat: true
        running: root.popups.length > 0
        onTriggered: {
            for (const e of root.popups) {
                if (e.timeout <= 0 || e.hovered)
                    continue;
                e.remaining -= interval;
                if (e.remaining <= 0)
                    root.expire(e);
            }
        }
    }

    // Focus mode survives a restart of the shell, since swayidle stays
    // stopped either way.
    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        onLoaded: root.dnd = true
    }

    IpcHandler {
        target: "notifications"

        function toggleFocus(): void {
            root.setDnd(!root.dnd);
        }
        function dismissAll(): void {
            root.dismissAll();
        }
        function clear(): void {
            root.clearHistory();
        }
    }
}
