//@ pragma IconTheme Adwaita

// The desktop shell for sway: a top bar per output with panels for the
// clock, WiFi, Bluetooth and tray menus, the notification server and its
// popups, the on-screen readout for volume, mic and brightness, the polkit
// password prompt, and the lock screen. Started by `exec_always quickshell
// --no-duplicate` in sway/config; edits here reload live.

import QtQuick
import Quickshell
import qs.bar
import qs.dialogs
import qs.lock
import qs.notifications
import qs.osd

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    NotificationPopups {}
    Osd {}
    Polkit {}
    Lock {}
}
