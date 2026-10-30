pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Hardware readings for the bar. Sysfs and /proc files are re-read in place
// on a timer instead of forking a process per tick; the GPU temperature
// streams from one long-running nvidia-smi, along with its memory use for
// the LLM panel.
Singleton {
    id: root

    property real cpuTemp: NaN
    property real gpuTemp: NaN
    // MiB, from the same nvidia-smi.
    property real gpuMemUsed: NaN
    property real gpuMemTotal: NaN
    property real memPct: NaN
    property var cpuPaths: []

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

    // 0..1, from the Control Center's slider.
    function setBrightness(level) {
        Quickshell.execDetached(["brightnessctl", "set", Math.round(Math.max(0.01, Math.min(1, level)) * 100) + "%"]);
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
        command: ["nvidia-smi", "--query-gpu=temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits", "-l", "2"]
        stdout: SplitParser {
            onRead: line => {
                const f = line.split(",").map(parseFloat);
                root.gpuTemp = f[0];
                root.gpuMemUsed = f[1];
                root.gpuMemTotal = f[2];
            }
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

    // The backlight's uevents include changes made by the hardware keys, so
    // a reading (and the on-screen readout) follows them at once rather than
    // on the next poll.
    Process {
        running: Theme.profile.backlight !== ""
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes(" change "))
                    brightnessTimer.restart();
            }
        }
    }

    // inotify doesn't see backlight changes in sysfs, so poll too; a scroll
    // on the block restarts the timer for a prompt update.
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
