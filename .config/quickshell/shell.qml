//@ pragma IconTheme Adwaita

// The desktop shell for sway: a top bar per output with panels for the
// clock, WiFi and Bluetooth, plus the notification server and its popups. Started by `exec quickshell` in sway/config;
// edits here reload live.

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
