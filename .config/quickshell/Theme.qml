pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Colors, fonts and sizes for the bar and its popups, plus the per-host
// profile. The host is picked by hostname, the same split sway makes with
// sway/hosts/<name>.conf.
Singleton {
    id: root

    readonly property string host: hostFile.text().trim()

    // fontPx matches the sway font on each host (JuliaMono 15 pt on the
    // workstation's unscaled 4K panel, 10 pt on the T470's 1080p one), and
    // every size below is derived from it. The flags pick the bar blocks
    // that machine has; cpuSensor names the hwmon chip and the label prefix
    // of the sensors to read (the hottest match wins), and backlight the
    // /sys/class/backlight device behind the brightness block. The Bluetooth
    // block shows whenever a controller is present; the flag keeps it there
    // while the controller is switched off (the T470's vanishes when
    // rfkill blocks it). fingerprint lets the lock screen take a finger on
    // the reader as well as the password, and llm shows the local LLM
    // server's block (.config/llm).
    readonly property var profiles: ({
        workstation: {
            fontPx: 20,
            barBg: "#000000",
            dim: "#b7b19c",
            low: "#b85c57",
            cpuSensor: { chip: "asusec", label: "CPU Package" },
            gpu: true,
            battery: false,
            backlight: "",
            wifi: false,
            bluetooth: false,
            fingerprint: false,
            llm: true
        },
        t470: {
            fontPx: 13,
            barBg: "#323232",
            dim: "#888888",
            low: "#ff5555",
            cpuSensor: { chip: "coretemp", label: "Core " },
            gpu: false,
            battery: true,
            backlight: "intel_backlight",
            wifi: true,
            bluetooth: true,
            fingerprint: true,
            llm: false
        }
    })
    readonly property var profile: profiles[host] ?? profiles.t470

    // Sizes
    readonly property int em: profile.fontPx
    readonly property int small: Math.round(em * 0.8)
    readonly property int barHeight: Math.round(em * 1.6)
    readonly property int gap: Math.round(em * 0.5)
    readonly property int radius: Math.round(em * 0.5)
    readonly property int notifWidth: em * 22
    readonly property int panelWidth: em * 26

    // Fonts
    readonly property string font: "JuliaMono"
    readonly property string iconFont: "Symbols Nerd Font Mono"

    // Bar colors, carried over from the swaybar setup: the orange accent
    // of the focused workspace and the warning shades of the readings.
    readonly property color barBg: profile.barBg
    readonly property color fg: "#ffffff"
    readonly property color dim: profile.dim
    readonly property color hover: Qt.tint(barBg, "#26ffffff")
    readonly property color accent: "#ffa500"
    readonly property color accentFg: "#000000"
    readonly property color warn: "#8f7634"
    readonly property color low: profile.low
    readonly property color good: "#57864e"
    readonly property color urgent: "#b85c57"
    // In-use indicators, after macOS: orange microphone, green camera,
    // purple screen sharing.
    readonly property color micInUse: "#ffa500"
    readonly property color cameraInUse: "#57b84e"
    readonly property color screenInUse: "#a77bdb"

    // Popup colors: the acme palette.
    readonly property color paper: "#ffffea"
    readonly property color paperHover: "#f4f4d4"
    readonly property color ink: "#000000"
    readonly property color inkDim: "#666666"
    readonly property color rule: "#8888cc"
    readonly property color highlight: "#eeee9e"
    readonly property color link: "#2a8dc5"
    readonly property color olive: "#99994c"
    readonly property color critical: "#b85c57"

    // Material Design glyphs from Symbols Nerd Font.
    readonly property var icons: ({
        cpu: String.fromCodePoint(0xF035B),
        ram: String.fromCodePoint(0xF061A),
        gpu: String.fromCodePoint(0xF08AE),
        volHigh: String.fromCodePoint(0xF057E),
        volMid: String.fromCodePoint(0xF0580),
        volLow: String.fromCodePoint(0xF057F),
        volOff: String.fromCodePoint(0xF0581),
        keyboard: String.fromCodePoint(0xF030C),
        bell: String.fromCodePoint(0xF009A),
        bellOff: String.fromCodePoint(0xF009B),
        wifiOff: String.fromCodePoint(0xF05AA),
        wifi: [0xF092F, 0xF091F, 0xF0922, 0xF0925, 0xF0928].map(c => String.fromCodePoint(c)),
        bluetooth: String.fromCodePoint(0xF00AF),
        bluetoothOff: String.fromCodePoint(0xF00B2),
        bluetoothOn: String.fromCodePoint(0xF00B1),
        battery: [0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079].map(c => String.fromCodePoint(c)),
        batteryCharging: String.fromCodePoint(0xF0084),
        brightness: String.fromCodePoint(0xF00DF),
        sync: String.fromCodePoint(0xF04E6),
        speaker: String.fromCodePoint(0xF04C3),
        headphones: String.fromCodePoint(0xF02CB),
        monitor: String.fromCodePoint(0xF0379),
        close: String.fromCodePoint(0xF0156),
        left: String.fromCodePoint(0xF0141),
        right: String.fromCodePoint(0xF0142),
        check: String.fromCodePoint(0xF012C),
        lock: String.fromCodePoint(0xF033E),
        refresh: String.fromCodePoint(0xF0450),
        power: String.fromCodePoint(0xF0425),
        mic: String.fromCodePoint(0xF036C),
        micOff: String.fromCodePoint(0xF036D),
        music: String.fromCodePoint(0xF075A),
        play: String.fromCodePoint(0xF040A),
        pause: String.fromCodePoint(0xF03E4),
        next: String.fromCodePoint(0xF04AD),
        previous: String.fromCodePoint(0xF04AE),
        search: String.fromCodePoint(0xF0349),
        clipboard: String.fromCodePoint(0xF014C),
        text: String.fromCodePoint(0xF09A8),
        image: String.fromCodePoint(0xF02E9),
        sleep: String.fromCodePoint(0xF0904),
        logout: String.fromCodePoint(0xF0343),
        restart: String.fromCodePoint(0xF0709),
        record: String.fromCodePoint(0xF044A),
        camera: String.fromCodePoint(0xF0100),
        calculator: String.fromCodePoint(0xF00EC),
        console: String.fromCodePoint(0xF018D),
        brain: String.fromCodePoint(0xF09D1),
        capture: String.fromCodePoint(0xF039D),
        ask: String.fromCodePoint(0xF1739),
        eyedropper: String.fromCodePoint(0xF020A)
    })

    FileView {
        id: hostFile
        path: "/proc/sys/kernel/hostname"
        blockLoading: true
    }
}
