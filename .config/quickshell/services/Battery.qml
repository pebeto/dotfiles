pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The T470's battery packs, for the bar and the battery panel: BAT0 is the
// internal pack and BAT1 the hot-swap one. Sysfs gives each pack's charge,
// power and wear, and the charge limit; the 24-hour history is what
// sway/battery-notify.sh records each time its timer runs.
//
// The charge limit is thinkpad_acpi's start and stop thresholds, which only
// root can change until the udev rule in quickshell/udev is installed
// (install.sh prints how). Both packs get the same limit, and a pack slid
// in takes the internal one's.
Singleton {
    id: root

    readonly property string sysfs: "/sys/class/power_supply"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/battery"

    // [{ name, capacity, status, energy, full, design, power, cycles, start,
    // stop, writable }], in Wh and W. start and stop are NaN on a pack
    // without a charge limit.
    property var packs: []
    property bool ac: false
    readonly property bool charging: packs.some(p => p.status === "Charging")
    readonly property bool discharging: packs.some(p => p.status === "Discharging")
    // Red only when one pack is empty and the other is at or below this,
    // so a drained hot-swap pack alone doesn't raise an alarm.
    readonly property int partnerLow: 15
    readonly property bool low: packs.length === 2
        && ((packs[0].capacity === 0 && packs[1].capacity <= partnerLow)
            || (packs[1].capacity === 0 && packs[0].capacity <= partnerLow))

    // Watts going in or out, smoothed over about half a minute, and which
    // way ("in", "out" or "").
    property real rate: NaN
    property string flow: ""
    // Hours until empty, or until the charge limit while charging.
    readonly property real timeLeft: rate > 0.1 ? (charging ? packs.reduce((sum, p) => sum + Math.max(0, p.full * (isNaN(p.stop) ? 100 : p.stop) / 100 - p.energy), 0) : packs.reduce((sum, p) => sum + p.energy, 0)) / rate : NaN
    // Hours the internal pack alone would last, once the external one is out.
    readonly property real internalAlone: discharging && packs.length === 2 && rate > 0.1 ? (packs.find(p => p.name === "BAT0")?.energy ?? NaN) / rate : NaN

    readonly property int careStart: 75
    readonly property int careStop: 80
    readonly property var limitable: packs.filter(p => !isNaN(p.stop))
    readonly property bool limitSupported: limitable.length > 0
    readonly property bool limitWritable: limitSupported && limitable.every(p => p.writable)
    readonly property int stop: limitSupported ? limitable[0].stop : 100
    readonly property bool limited: stop < 100
    // Charging to 100% until both packs are full, then back to the limit.
    property bool fullOnce: false

    // [{ level, state }] per half hour over the last day, oldest first, and
    // null where nothing was recorded (asleep or off). state is "c" if it
    // charged at all in that half hour, "a" for plugged in and "d" for on
    // battery.
    property var history: []
    // power-profiles-daemon can be reached on the system bus.
    property bool profiles: false

    function refresh() {
        poll.running = true;
        profileCheck.running = true;
        historyFile.reload();
    }

    function setLimit(on) {
        writeLimit(on ? careStart : 0, on ? careStop : 100);
        if (fullOnce) {
            fullOnce = false;
            Quickshell.execDetached(["rm", "-f", stateDir + "/full-once"]);
        }
    }

    function chargeFullOnce() {
        writeLimit(0, 100);
        fullOnce = true;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && touch "$1/full-once"', "sh", stateDir]);
    }

    // The start threshold drops to 0 first, so the stop one can move either
    // way: the firmware refuses a start above the stop.
    function writeLimit(start, stop, packs) {
        const dirs = (packs ?? limitable).map(p => sysfs + "/" + p.name);
        writer.command = ["sh", "-c", 'start=$1 stop=$2; shift 2; for d; do echo 0 > "$d/charge_control_start_threshold"; echo "$stop" > "$d/charge_control_end_threshold"; echo "$start" > "$d/charge_control_start_threshold"; done', "sh", String(start), String(stop), ...dirs];
        writer.running = true;
    }

    function update(text) {
        const num = s => s === undefined || s === "" ? NaN : Number(s);
        const packs = [];
        let ac = false;
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            if (f[0] === "ac")
                ac = ac || f[1] === "1";
            else if (f[0] === "bat")
                packs.push({
                    name: f[1],
                    capacity: parseInt(f[2]),
                    status: f[3],
                    energy: num(f[4]) / 1e6,
                    full: num(f[5]) / 1e6,
                    design: num(f[6]) / 1e6,
                    power: num(f[7]) / 1e6,
                    cycles: num(f[8]),
                    start: num(f[9]),
                    stop: num(f[10]),
                    writable: f[11] === "1"
                });
        }

        const flow = packs.some(p => p.status === "Charging") ? "in" : packs.some(p => p.status === "Discharging") ? "out" : "";
        const raw = packs.filter(p => p.status === (flow === "in" ? "Charging" : "Discharging")).reduce((sum, p) => sum + (p.power || 0), 0);
        rate = flow === "" ? NaN : flow !== root.flow || isNaN(rate) ? raw : rate * 0.8 + raw * 0.2;
        root.flow = flow;

        const grew = packs.length > root.packs.length;
        root.packs = packs;
        root.ac = ac;

        const limitable = packs.filter(p => !isNaN(p.stop));
        if (grew && limitable.length > 1 && limitable.every(p => p.writable) && limitable.some(p => p.stop !== limitable[0].stop || p.start !== limitable[0].start))
            writeLimit(limitable[0].start, limitable[0].stop, limitable.slice(1));
        if (fullOnce && packs.length > 0 && packs.every(p => p.status === "Full" || p.capacity >= 99))
            setLimit(true);
    }

    function slots(text) {
        const span = 1800;
        const count = 48;
        const now = Date.now() / 1000;
        const out = new Array(count).fill(null);
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            const i = count - 1 - Math.floor((now - Number(f[0])) / span);
            if (!(i >= 0 && i < count) || f.length < 3)
                continue;
            out[i] = { level: Number(f[1]), state: out[i]?.state === "c" ? "c" : f[2] };
        }
        return out;
    }

    Process {
        id: poll

        command: ["sh", "-c", [
            'cd "$1" || exit 0',
            'r() { cat "$d/$1" 2>/dev/null; }',
            'for d in *; do',
            '    case "$(r type)" in',
            '    Mains) printf "ac\\t%s\\n" "$(r online)" ;;',
            '    Battery)',
            '        case "$d" in BAT*) ;; *) continue ;; esac',
            '        w=0; [ -w "$d/charge_control_end_threshold" ] && w=1',
            '        printf "bat\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" "$d" "$(r capacity)" "$(r status)" "$(r energy_now)" "$(r energy_full)" "$(r energy_full_design)" "$(r power_now)" "$(r cycle_count)" "$(r charge_control_start_threshold)" "$(r charge_control_end_threshold)" "$w" ;;',
            '    esac',
            'done'
        ].join("\n"), "sh", root.sysfs]
        stdout: StdioCollector {
            onStreamFinished: root.update(text)
        }
    }

    Timer {
        interval: 5000
        running: Theme.profile.battery
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    Process {
        id: writer
        onExited: poll.running = true
    }

    Process {
        running: Theme.profile.battery
        command: ["test", "-e", root.stateDir + "/full-once"]
        onExited: code => root.fullOnce = code === 0
    }

    Process {
        id: profileCheck
        running: Theme.profile.battery
        command: ["sh", "-c", "busctl --system list --no-legend 2>/dev/null | grep -q '^org.freedesktop.UPower.PowerProfiles '"]
        onExited: code => root.profiles = code === 0
    }

    FileView {
        id: historyFile
        path: root.stateDir + "/history.tsv"
        printErrors: false
        onLoaded: root.history = root.slots(text())
        onLoadFailed: root.history = []
    }
}
