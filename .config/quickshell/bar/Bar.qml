import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.panels
import qs.services

// The top bar on one output: workspaces on the left, readings and the clock
// on the right. Which readings show up is set per host in Theme.profiles.
PanelWindow {
    id: bar

    required property var modelData
    readonly property string outputName: modelData.name
    readonly property int panelMax: modelData.height - Theme.barHeight - Theme.gap * 2

    // [normal, warning, critical] for System.level().
    function levelColor(level) {
        return [Theme.fg, Theme.warn, Theme.low][level];
    }

    screen: modelData
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: Theme.barHeight
    color: Theme.barBg
    WlrLayershell.namespace: "quickshell-bar"

    Workspaces {
        anchors.left: parent.left
        anchors.leftMargin: Math.round(Theme.gap * 0.3)
        screen: bar.modelData
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Math.round(Theme.gap * 0.3)
        height: parent.height

        // Tray icons of apps that keep running with their windows closed
        // (Steam, Slack). Double click opens the app's window (see Tray.qml),
        // right click opens its menu, middle click is its secondary action.
        Repeater {
            model: Tray.items

            BarBlock {
                id: trayBlock

                required property SystemTrayItem modelData

                visible: modelData.status !== Status.Passive
                function showMenu() {
                    if (modelData.hasMenu) {
                        const p = trayBlock.mapToItem(null, 0, trayBlock.height);
                        modelData.display(bar, p.x, p.y);
                    }
                }

                onClicked: button => {
                    if (button === Qt.MiddleButton)
                        modelData.secondaryActivate();
                    else if (button === Qt.RightButton)
                        showMenu();
                }
                onDoubleClicked: button => {
                    if (button !== Qt.LeftButton)
                        return;
                    if (modelData.onlyMenu)
                        showMenu();
                    else
                        Tray.open(modelData, showMenu);
                }
                onWheel: steps => modelData.scroll(steps * 120, false)

                IconImage {
                    // Quickshell ignores the ?path= an app adds for an icon kept
                    // in its own folder (Steam does), so load that file directly.
                    source: {
                        const icon = trayBlock.modelData.icon;
                        const at = icon.indexOf("?path=");
                        if (at < 0)
                            return icon;
                        return "file://" + icon.slice(at + 6) + "/" + icon.slice(0, at).replace("image://icon/", "") + ".png";
                    }
                    implicitSize: Math.round(Theme.em * 1.1)
                }
            }
        }

        // Focus mode: notifications held back and swayidle paused.
        BarBlock {
            onClicked: Notifs.setDnd(!Notifs.dnd)

            Segment {
                icon: Notifs.dnd ? Theme.icons.bellOff : Theme.icons.bell
                label: !Notifs.dnd ? "" : Notifs.missed > 0 ? "focus · " + Notifs.missed : "focus"
                tint: Notifs.dnd ? Theme.good : Theme.fg
                iconTint: Notifs.dnd ? Theme.good : Theme.dim
            }
        }

        BarBlock {
            onClicked: Sway.nextLayout()

            Segment {
                icon: Theme.icons.keyboard
                label: Sway.layout
            }
        }

        // Temperatures and memory; a click opens btop.
        BarBlock {
            onClicked: btop.running = !btop.running

            Segment {
                readonly property int level: System.level(System.cpuTemp, 70, 85)
                icon: Theme.icons.cpu
                label: isNaN(System.cpuTemp) ? "?" : Math.round(System.cpuTemp) + "°"
                tint: bar.levelColor(level)
            }
            Segment {
                readonly property int level: System.level(System.gpuTemp, 70, 85)
                visible: Theme.profile.gpu
                icon: Theme.icons.gpu
                label: isNaN(System.gpuTemp) ? "?" : Math.round(System.gpuTemp) + "°"
                tint: bar.levelColor(level)
            }
            Segment {
                readonly property int level: System.level(System.memPct, 80, 90)
                icon: Theme.icons.ram
                label: isNaN(System.memPct) ? "?" : System.memPct + "%"
                tint: bar.levelColor(level)
            }
        }

        BarBlock {
            visible: Theme.profile.backlight !== ""
            onWheel: steps => System.stepBrightness(steps)

            Segment {
                icon: Theme.icons.brightness
                label: isNaN(System.brightness) ? "?" : System.brightness + "%"
            }
        }

        // Left or middle click mutes; right click opens the clock panel,
        // which lists the outputs to switch to.
        BarBlock {
            onClicked: button => button === Qt.RightButton ? Panels.toggle("clock", bar.outputName) : Audio.toggleMute()
            onWheel: steps => Audio.step(steps)

            Segment {
                icon: Audio.muted ? Theme.icons.volOff : Audio.volume >= 0.66 ? Theme.icons.volHigh : Audio.volume >= 0.33 ? Theme.icons.volMid : Theme.icons.volLow
                label: isNaN(Audio.volume) ? "?" : Audio.muted ? "muted" : Math.round(Audio.volume * 100) + "%"
                tint: Audio.muted ? Theme.dim : Theme.fg
            }
        }

        // One reading per pack: i for the internal one, e for the hot-swap.
        BarBlock {
            id: batteryBlock

            readonly property real average: System.batteries.reduce((sum, b) => sum + b.capacity, 0) / Math.max(1, System.batteries.length)
            visible: Theme.profile.battery && System.batteries.length > 0
            interactive: false

            Segment {
                icon: System.charging ? Theme.icons.batteryCharging : Theme.icons.battery[Math.round(batteryBlock.average / 10)]
                label: System.batteries.map(b => (({ BAT0: "i", BAT1: "e" })[b.name] ?? "") + b.capacity + "%").join(" ")
                tint: System.batteryLow ? Theme.low : Theme.fg
            }
        }

        BarBlock {
            id: wifiBlock

            visible: Theme.profile.wifi
            onClicked: Panels.toggle("wifi", bar.outputName)

            Segment {
                icon: System.wifiState === "off" ? Theme.icons.wifiOff : Theme.icons.wifi[System.wifiState === "connected" ? System.wifiSignal : 0]
                label: System.wifiState === "connected" ? System.wifiSsid : System.wifiState === "off" ? "off" : "on"
                tint: System.wifiState === "connected" ? Theme.fg : Theme.dim
            }
        }

        BarBlock {
            id: bluetoothBlock

            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

            visible: adapter !== null || Theme.profile.bluetooth
            onClicked: Panels.toggle("bluetooth", bar.outputName)

            Segment {
                icon: !bluetoothBlock.adapter?.enabled ? Theme.icons.bluetoothOff : bluetoothBlock.connected.length > 0 ? Theme.icons.bluetoothOn : Theme.icons.bluetooth
                label: bluetoothBlock.connected.length === 1 ? bluetoothBlock.connected[0].name : bluetoothBlock.connected.length > 1 ? bluetoothBlock.connected.length + " devices" : ""
                tint: bluetoothBlock.adapter?.enabled ? Theme.fg : Theme.dim
            }
        }

        BarBlock {
            id: clockBlock
            onClicked: Panels.toggle("clock", bar.outputName)

            Segment {
                label: Qt.formatDateTime(clock.date, "ddd dd HH:mm")
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // btop in a floating foot window (the btop-popup rule in sway/config);
    // clicking the block again closes it.
    Process {
        id: btop
        command: ["foot", "--app-id=btop-popup", "--", "btop"]
    }

    ClockPanel {
        anchorItem: clockBlock
        screen: bar.modelData
        maxHeight: bar.panelMax
    }

    WifiPanel {
        anchorItem: wifiBlock
        screen: bar.modelData
        maxHeight: bar.panelMax
    }

    BluetoothPanel {
        anchorItem: bluetoothBlock
        screen: bar.modelData
        maxHeight: bar.panelMax
    }
}
