import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.components

// Paired and nearby Bluetooth devices. The list and their state come from
// bluez through Quickshell; the actions go through scripts/bluetooth.sh, the
// same bluetoothctl steps the old picker took. It scans while open.
PanelPopup {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/bluetooth.sh")
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    // bluez names a device that advertises no name after its own address
    // (dash-separated); those are nearby noise unless already paired.
    readonly property var devices: (adapter?.devices.values ?? [])
        .filter(d => d.paired || (d.name && d.name.replace(/-/g, ":").toUpperCase() !== d.address.toUpperCase()))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
    property string busy: ""
    property string message: ""

    function toggle(d) {
        if (busy)
            return;
        busy = d.address;
        message = (d.connected ? "Disconnecting " : "Connecting ") + d.name + "…";
        actionProc.label = d.name;
        actionProc.command = [script, d.connected ? "disconnect" : "connect", d.address];
        actionProc.running = true;
    }

    name: "bluetooth"
    contentWidth: Theme.em * 20
    onOpened: {
        message = "";
        if (on)
            adapter.discovering = true;
    }
    onWantedChanged: {
        if (!wanted && adapter?.discovering)
            adapter.discovering = false;
    }

    Process {
        id: actionProc

        property string label

        stdout: StdioCollector {
            onStreamFinished: {
                root.message = text.trim() === "ok" ? "" : "Couldn't reach " + actionProc.label;
                root.busy = "";
            }
        }
    }

    Item {
        width: root.contentWidth
        height: powerButton.implicitHeight

        SectionTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: "Bluetooth" + (root.adapter?.discovering ? "  ·  scanning" : "")
        }

        TextButton {
            id: powerButton
            anchors.right: parent.right
            text: root.on ? "Turn off" : "Turn on"
            onClicked: Quickshell.execDetached([root.script, root.on ? "off" : "on"])
        }
    }

    Ink {
        visible: !root.on
        text: root.adapter ? "Bluetooth is off" : "No controller (blocked or bluetoothd stopped)"
        width: root.contentWidth
        wrapMode: Text.Wrap
        color: Theme.inkDim
    }

    Column {
        visible: root.on
        width: root.contentWidth
        spacing: 2

        Repeater {
            model: root.devices

            Rectangle {
                id: row

                required property var modelData

                width: root.contentWidth
                height: Math.round(Theme.em * 1.7)
                radius: Math.round(Theme.radius * 0.6)
                color: modelData.connected ? Theme.highlight : rowMouse.containsMouse ? Theme.paperHover : "transparent"

                Row {
                    x: Math.round(Theme.gap * 0.6)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.gap

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: Math.round(Theme.em * 1.1)
                        source: Quickshell.iconPath(row.modelData.icon || "bluetooth", "bluetooth")
                    }
                    Ink {
                        text: row.modelData.name
                        font.bold: row.modelData.connected
                    }
                }

                Ink {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(Theme.gap * 0.6)
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Theme.small
                    color: Theme.inkDim
                    text: {
                        const d = row.modelData;
                        if (root.busy === d.address || d.state === BluetoothDeviceState.Connecting)
                            return "…";
                        if (d.connected)
                            return d.batteryAvailable ? Math.round(d.battery * 100) + "%" : "connected";
                        return d.paired ? "paired" : "";
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggle(row.modelData)
                }
            }
        }

        Ink {
            visible: root.devices.length === 0
            text: "No devices yet"
            color: Theme.inkDim
        }
    }

    Ink {
        visible: root.message !== ""
        width: root.contentWidth
        wrapMode: Text.Wrap
        text: root.message
        color: root.message.startsWith("Couldn't") ? Theme.critical : Theme.inkDim
    }
}
