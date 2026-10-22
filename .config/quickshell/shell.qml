//@ pragma IconTheme Adwaita
//@ pragma UseQApplication

// The desktop shell for sway: a top bar per output with panels for the
// clock, WiFi and Bluetooth, plus the notification server and its popups. Started by `exec quickshell` in sway/config;
// edits here reload live, except the pragmas above, which need a restart.
// UseQApplication is for the tray menus, which are Qt platform menus.

import QtQuick
import Quickshell
import qs.bar
import qs.notifications

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    NotificationPopups {}
}
