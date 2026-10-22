pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// Opening a tray app's window. Most icons do that themselves when activated,
// but libappindicator ones (Steam) have no Activate method, only a menu. For
// those the app's desktop entry runs instead, which brings a running
// single-instance app to the front. scripts/tray.sh does the activating and
// reports whether it worked.
Singleton {
    id: root

    // The bar's tray model. Taking it from here creates this singleton with
    // the bar, so the desktop entries, which load on first use, are ready
    // before the first click needs one.
    readonly property var items: SystemTray.items
    readonly property var entries: DesktopEntries.applications

    // The item whose menu panels/TrayMenu.qml shows.
    property var menuItem: null

    property var pending: null
    property var pendingFallback: null

    // fallback runs when the app can't be opened either way, so the caller
    // can show its menu instead.
    function open(item, fallback) {
        pending = item;
        pendingFallback = fallback;
        check.command = [Quickshell.shellPath("scripts/tray.sh"), item.id];
        check.running = true;
    }

    Process {
        id: check
        onExited: exitCode => {
            const item = root.pending;
            const fallback = root.pendingFallback;
            root.pending = root.pendingFallback = null;
            // Activated, or the app quit since the click.
            if (exitCode === 0 || !item)
                return;
            const entry = DesktopEntries.byId(item.id) ?? DesktopEntries.heuristicLookup(item.id);
            if (entry)
                entry.execute();
            else
                fallback();
        }
    }
}
