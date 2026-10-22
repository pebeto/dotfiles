pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Hardware readings for the bar. Sysfs and /proc files are re-read in place
// on a timer instead of forking a process per tick; the GPU temperature
// streams from one long-running nvidia-smi.
Singleton {
    id: root

    property real cpuTemp: NaN
    property real gpuTemp: NaN
    property real memPct: NaN
    property var cpuPaths: []

    // Battery packs as [{ name, capacity, status }]: BAT0 is the T470's
    // internal pack and BAT1 the hot-swap one.
    property var batteries: []
    readonly property bool charging: batteries.some(b => b.status === "Charging")
    // Red only when one pack is empty and the other is at or below this,
    // so a drained hot-swap pack alone doesn't raise an alarm.
    readonly property int batteryPartnerLow: 15
    readonly property bool batteryLow: batteries.length === 2
        && ((batteries[0].capacity === 0 && batteries[1].capacity <= batteryPartnerLow)
            || (batteries[1].capacity === 0 && batteries[0].capacity <= batteryPartnerLow))

    property real brightness: NaN
    readonly property string backlightDir: "/sys/class/backlight/" + Theme.profile.backlight

    // "off" (radio blocked), "on" (not associated) or "connected".
    property string wifiState: ""
    property string wifiSsid: ""
    property int wifiSignal: 0

    // 0, 1 or 2 for below the warning threshold, at or above it, and at or
    // above the critical one. The bar's thresholds: temperatures 70/85 °C,
    // memory 80/90 %.
    function level(value, warn, crit) {
        if (isNaN(value))
            return 0;
        return value >= crit ? 2 : value >= warn ? 1 : 0;
    }

    function stepBrightness(steps) {
        const pct = Math.abs(steps) * 5 + "%" + (steps > 0 ? "+" : "-");
        Quickshell.execDetached(["brightnessctl", "set", pct]);
        brightnessTimer.restart();
    }

    function refreshWifi() {
        if (Theme.profile.wifi)
            wifiProc.running = true;
    }

    // Find the temperature inputs matching the host's cpuSensor once; the
    // hwmon numbering can change between boots, the chip names don't.
    Process {
        running: true
        command: ["sh", "-c", "for f in /sys/class/hwmon/hwmon*/temp*_label; do printf '%s\\t%s\\t%s\\n' \"$(cat \"${f%/*}/name\")\" \"$(cat \"$f\")\" \"${f%_label}_input\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const want = Theme.profile.cpuSensor;
                root.cpuPaths = text.trim().split("\n").map(l => l.split("\t")).filter(f => f[0] === want.chip && (f[1] ?? "").startsWith(want.label)).map(f => f[2]);
            }
        }
    }

    Variants {
        id: cpuFiles
        model: root.cpuPaths

        FileView {
            required property string modelData
            path: modelData
            blockLoading: true
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        blockLoading: true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let hottest = NaN;
            for (const f of cpuFiles.instances) {
                f.reload();
                const t = parseInt(f.text()) / 1000;
                if (!isNaN(t) && (isNaN(hottest) || t > hottest))
                    hottest = t;
            }
            root.cpuTemp = hottest;

            meminfo.reload();
            const m = meminfo.text();
            const total = parseInt(m.match(/MemTotal:\s+(\d+)/)?.[1]);
            const avail = parseInt(m.match(/MemAvailable:\s+(\d+)/)?.[1]);
            root.memPct = total > 0 ? Math.round((total - avail) * 100 / total) : NaN;
        }
    }

    Process {
        id: gpuProc
        running: Theme.profile.gpu
        command: ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits", "-l", "2"]
        stdout: SplitParser {
            onRead: line => root.gpuTemp = parseFloat(line)
        }
        // nvidia-smi exits when the driver goes away (a reload, say); try
        // again a little later rather than leaving a stale reading.
        onExited: {
            root.gpuTemp = NaN;
            gpuRestart.start();
        }
    }

    Timer {
        id: gpuRestart
        interval: 5000
        onTriggered: gpuProc.running = Theme.profile.gpu
    }

    Process {
        id: batteryProc
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -d \"$b\" ] && printf '%s\\t%s\\t%s\\n' \"${b##*/}\" \"$(cat \"$b/capacity\")\" \"$(cat \"$b/status\")\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim() ? text.trim().split("\n") : [];
                root.batteries = lines.map(l => {
                    const f = l.split("\t");
                    return { name: f[0], capacity: parseInt(f[1]), status: f[2] };
                });
            }
        }
    }

    Timer {
        interval: 5000
        running: Theme.profile.battery
        repeat: true
        triggeredOnStart: true
        onTriggered: batteryProc.running = true
    }

    FileView {
        id: brightnessNow
        path: Theme.profile.backlight ? root.backlightDir + "/brightness" : ""
        blockLoading: true
    }

    FileView {
        id: brightnessMax
        path: Theme.profile.backlight ? root.backlightDir + "/max_brightness" : ""
        blockLoading: true
    }

    // sysfs doesn't report backlight changes made by the hardware keys, so
    // poll; a scroll on the block restarts the timer for a prompt update.
    Timer {
        id: brightnessTimer
        interval: 1000
        running: Theme.profile.backlight !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            brightnessNow.reload();
            const max = parseInt(brightnessMax.text());
            root.brightness = max > 0 ? Math.round(parseInt(brightnessNow.text()) * 100 / max) : NaN;
        }
    }

    Process {
        id: wifiProc
        command: [Quickshell.shellPath("scripts/wifi.sh"), "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\t");
                root.wifiState = f[0];
                root.wifiSsid = f[1] ?? "";
                const dbm = parseInt(f[2]);
                root.wifiSignal = isNaN(dbm) ? 0 : dbm >= -55 ? 4 : dbm >= -65 ? 3 : dbm >= -75 ? 2 : dbm >= -85 ? 1 : 0;
            }
        }
    }

    Timer {
        interval: 5000
        running: Theme.profile.wifi
        repeat: true
        triggeredOnStart: true
        onTriggered: wifiProc.running = true
    }
}
