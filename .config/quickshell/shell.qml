//@ pragma IconTheme Adwaita

// The desktop shell for sway: a top bar per output with panels for the
// clock, WiFi, Bluetooth, tray menus and the local LLM server, the app
// launcher and clipboard picker, the session menu, the notification server
// and its popups, the on-screen readout for volume, mic and brightness, the
// screenshot thumbnail, the polkit password prompt, and the lock screen. Started by `exec_always quickshell --no-duplicate` in sway/config;
// edits here reload live.

import QtQuick
import Quickshell
import qs.bar
import qs.dialogs
import qs.launcher
import qs.lock
import qs.notifications
import qs.osd

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Launcher {}
    NotificationPopups {}
    Osd {}
    Screenshot {}
    Polkit {}
    Session {}
    Lock {}
}
