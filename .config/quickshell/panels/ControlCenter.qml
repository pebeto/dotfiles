import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.components
import qs.services

// The Control Center, from the icon next to the clock: quick toggles, the
// sound, the microphone, what's playing and Syncthing. Laptops (Theme's
// wifi, bluetooth and backlight flags) also get WiFi and Bluetooth tiles,
// which open their own panels, and a brightness slider. A right click on
// Focus or Keep awake offers a time limit, and Screenshot asks what to take,
// both in a row under the tiles.
PanelPopup {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property int columns: 3
    readonly property int tileWidth: Math.floor((contentWidth - Theme.gap * (columns - 1)) / columns)
    // The tile whose choices show under the tiles: "focus", "awake", "shot"
    // or "".
    property string choosing: ""

    // Time left on a timed toggle. Reading clock.date makes a binding on
    // this tick each minute; the time itself is now, not the minute's start.
    function remaining(until) {
        const left = clock.date ? until - Date.now() : 0;
        if (left > 90 * 60000)
            return "until " + Qt.formatTime(new Date(until), "HH:mm");
        return Math.max(1, Math.ceil(left / 60000)) + " min";
    }

    // The next 8:00, today's or tomorrow's.
    function morning() {
        const d = new Date();
        d.setHours(8, 0, 0, 0);
        if (d.getTime() <= Date.now())
            d.setDate(d.getDate() + 1);
        return d.getTime();
    }

    function choices() {
        if (choosing === "shot")
            return [["a region", "region"], ["a window", "window"], ["the screen", "screen"]];
        return [["30 min", Date.now() + 30 * 60000], ["1 hour", Date.now() + 60 * 60000], ["Until 8:00", morning()]];
    }

    function choose(value) {
        const what = choosing;
        choosing = "";
        if (what === "focus") {
            Notifs.setDnd(true, value);
        } else if (what === "awake") {
            Notifs.setKeepAwake(true, value);
        } else {
            // Closed first, so the panel isn't in the shot.
            Panels.close();
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/sway/screenshot.sh", value]);
        }
    }

    name: "control"
    onOpened: {
        choosing = "";
        Syncthing.update();
        NightLight.refresh();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Grid {
        width: root.contentWidth
        columns: root.columns
        spacing: Theme.gap

        Tile {
            width: root.tileWidth
            icon: Notifs.quiet ? Theme.icons.bellOff : Theme.icons.bell
            label: "Focus"
            detail: Notifs.dnd ? (Notifs.focusUntil > 0 ? root.remaining(Notifs.focusUntil) : Notifs.missed > 0 ? Notifs.missed + " missed" : "on") : Notifs.held ? "held" : "off"
            on: Notifs.dnd
            onClicked: Notifs.setDnd(!Notifs.dnd)
            onRightClicked: root.choosing = root.choosing === "focus" ? "" : "focus"
        }
        // The screen doesn't lock or blank, and notifications still show.
        Tile {
            width: root.tileWidth
            icon: Theme.icons.coffee
            label: "Keep awake"
            detail: Notifs.keepAwake ? (Notifs.keepAwakeUntil > 0 ? root.remaining(Notifs.keepAwakeUntil) : "on") : Notifs.dnd ? "with focus" : "off"
            on: Notifs.keepAwake
            onClicked: Notifs.setKeepAwake(!Notifs.keepAwake)
            onRightClicked: root.choosing = root.choosing === "awake" ? "" : "awake"
        }
        Tile {
            width: root.tileWidth
            icon: Theme.icons.night
            label: "Night light"
            detail: !NightLight.available ? "not running" : NightLight.on ? "on" : "off"
            on: NightLight.available && NightLight.on
            onClicked: NightLight.toggle()
        }
        Tile {
            width: root.tileWidth
            icon: Audio.micMuted ? Theme.icons.micOff : Theme.icons.mic
            label: "Microphone"
            detail: !Audio.source ? "none" : Audio.micMuted ? "muted" : "on"
            on: Audio.source !== null && !Audio.micMuted
            onClicked: Audio.toggleMic()
        }
        Tile {
            width: root.tileWidth
            icon: Theme.icons.screenshot
            label: "Screenshot"
            detail: "region, window…"
            on: root.choosing === "shot"
            onClicked: root.choosing = root.choosing === "shot" ? "" : "shot"
        }
        Tile {
            width: root.tileWidth
            icon: Theme.icons.record
            label: "Record"
            detail: Recording.active ? Math.floor(Recording.elapsed / 60) + ":" + String(Recording.elapsed % 60).padStart(2, "0") : "a region"
            on: Recording.active
            onClicked: {
                // Closed first, so the panel isn't in the recording.
                Panels.close();
                Recording.toggle();
            }
        }
        Tile {
            width: root.tileWidth
            icon: Theme.icons.keyboard
            label: "Layout"
            detail: Sway.layout
            onClicked: Sway.nextLayout()
        }
        Tile {
            visible: Theme.profile.wifi
            width: root.tileWidth
            icon: System.wifiState === "off" ? Theme.icons.wifiOff : Theme.icons.wifi[System.wifiState === "connected" ? System.wifiSignal : 0]
            label: "WiFi"
            detail: System.wifiState === "connected" ? System.wifiSsid : System.wifiState === "off" ? "off" : "on"
            on: System.wifiState !== "off" && System.wifiState !== ""
            onClicked: Panels.toggle("wifi", Panels.screen)
        }
        Tile {
            visible: root.adapter !== null || Theme.profile.bluetooth
            width: root.tileWidth
            icon: !root.adapter?.enabled ? Theme.icons.bluetoothOff : root.btConnected.length > 0 ? Theme.icons.bluetoothOn : Theme.icons.bluetooth
            label: "Bluetooth"
            detail: !root.adapter?.enabled ? "off" : root.btConnected[0]?.name ?? "on"
            on: root.adapter?.enabled ?? false
            onClicked: Panels.toggle("bluetooth", Panels.screen)
        }
    }

    Column {
        visible: root.choosing !== ""
        width: root.contentWidth
        spacing: Math.round(Theme.gap * 0.6)

        Ink {
            text: root.choosing === "focus" ? "Focus for" : root.choosing === "awake" ? "Keep awake for" : "Screenshot of"
            color: Theme.inkDim
            font.pixelSize: Theme.small
        }
        Row {
            spacing: Theme.gap

            Repeater {
                // Worked out when the row opens, so "30 min" counts from then.
                model: root.choosing !== "" ? root.choices() : []

                TextButton {
                    required property var modelData

                    text: modelData[0]
                    onClicked: root.choose(modelData[1])
                }
            }
        }
    }

    Item {
        visible: Theme.profile.backlight !== ""
        width: root.contentWidth
        height: Math.round(Theme.em * 1.8)

        Glyph {
            id: sun
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.icons.brightness
            color: Theme.ink
        }
        Ink {
            id: brightness
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(Theme.em * 3)
            horizontalAlignment: Text.AlignRight
            text: isNaN(System.brightness) ? "?" : System.brightness + "%"
        }
        VolumeSlider {
            anchors.left: sun.right
            anchors.leftMargin: Theme.gap
            anchors.right: brightness.left
            anchors.rightMargin: Theme.gap
            anchors.verticalCenter: parent.verticalCenter
            value: System.brightness / 100
            onMoved: v => System.setBrightness(v)
            onStepped: steps => System.stepBrightness(steps)
        }
    }

    Rule {}

    Column {
        width: root.contentWidth
        spacing: Theme.gap

        SectionTitle {
            text: "Sound"
        }
        SoundView {
            width: parent.width
        }
    }

    Column {
        width: root.contentWidth
        spacing: Theme.gap

        SectionTitle {
            text: "Microphone"
        }
        MicView {
            width: parent.width
        }
    }

    // Only while some player has something loaded.
    Rule {
        visible: media.player !== null
    }
    Column {
        visible: media.player !== null
        width: root.contentWidth
        spacing: Theme.gap

        SectionTitle {
            text: "Now playing"
        }
        MediaView {
            id: media
            width: parent.width
        }
    }

    Rule {}

    Row {
        width: root.contentWidth
        spacing: Theme.gap

        Glyph {
            text: Theme.icons.sync
            color: Theme.ink
        }
        Ink {
            text: "Syncthing"
        }
        Ink {
            width: parent.width - x
            text: (Syncthing.state === "synced" ? "up to date" : Syncthing.state === "syncing" ? "syncing " + Syncthing.percent + "%" : "offline") + (Syncthing.state === "offline" ? "" : Syncthing.connected.length > 0 ? " · " + Syncthing.connected.join(", ") : " · no devices")
            color: Syncthing.state === "synced" ? Theme.good : Syncthing.state === "syncing" ? Theme.olive : Theme.inkDim
            elide: Text.ElideRight
        }
    }
}
