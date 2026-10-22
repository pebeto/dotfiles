import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Nearby networks from iwd (scripts/wifi.sh). Click one to join it; a
// protected network that iwd has no passphrase for asks for one here.
PanelPopup {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/wifi.sh")
    readonly property bool radioOff: System.wifiState === "off"
    // [{ connected, known, security, bars, ssid }]
    property var networks: []
    property bool scanning: false
    property string asking: ""
    property string joining: ""
    property string message: ""

    function scan() {
        scanning = true;
        listProc.running = true;
    }

    function join(net) {
        if (net.connected || joining)
            return;
        if (!net.known && net.security !== "open" && asking !== net.ssid) {
            asking = net.ssid;
            message = "";
            return;
        }
        connect(net.ssid, asking === net.ssid ? passphrase.text : "");
    }

    function connect(ssid, pass) {
        joining = ssid;
        message = "Joining " + ssid + "…";
        connectProc.command = [script, "connect", ssid, ...(pass ? [pass] : [])];
        connectProc.running = true;
    }

    function setRadio(on) {
        message = "";
        Quickshell.execDetached([script, "power", on ? "on" : "off"]);
        if (on)
            rescanTimer.restart();
        else
            networks = [];
        System.refreshWifi();
    }

    name: "wifi"
    contentWidth: Theme.em * 20
    onOpened: {
        asking = "";
        message = "";
        if (!radioOff)
            scan();
    }

    Process {
        id: listProc
        command: [root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.networks = text.trim().split("\n").filter(l => l).map(l => {
                    const f = l.split("\t");
                    return { connected: f[0] === "1", known: f[1] === "1", security: f[2], bars: parseInt(f[3]), ssid: f.slice(4).join("\t") };
                });
                root.scanning = false;
            }
        }
    }

    Process {
        id: connectProc
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = text.trim() === "ok";
                root.message = ok ? "Connected to " + root.joining : "Couldn't join " + root.joining;
                if (ok)
                    root.asking = "";
                root.joining = "";
                System.refreshWifi();
                root.scan();
            }
        }
    }

    // The radio takes a moment to come up after rfkill unblocks it.
    Timer {
        id: rescanTimer
        interval: 2500
        onTriggered: root.scan()
    }

    Item {
        width: root.contentWidth
        height: powerButton.implicitHeight

        SectionTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: "Wi-Fi" + (root.scanning ? "  ·  scanning" : "")
        }

        Row {
            anchors.right: parent.right
            spacing: Math.round(Theme.gap * 0.5)

            TextButton {
                visible: !root.radioOff
                text: "Rescan"
                onClicked: root.scan()
            }
            TextButton {
                id: powerButton
                text: root.radioOff ? "Turn on" : "Turn off"
                onClicked: root.setRadio(root.radioOff)
            }
        }
    }

    Ink {
        visible: root.radioOff
        text: "Wi-Fi is off"
        color: Theme.inkDim
    }

    Column {
        visible: !root.radioOff
        width: root.contentWidth
        spacing: 2

        Repeater {
            model: root.networks

            Column {
                id: net

                required property var modelData

                width: root.contentWidth
                spacing: 2

                Rectangle {
                    width: parent.width
                    height: Math.round(Theme.em * 1.7)
                    radius: Math.round(Theme.radius * 0.6)
                    color: net.modelData.connected ? Theme.highlight : netMouse.containsMouse ? Theme.paperHover : "transparent"

                    Row {
                        x: Math.round(Theme.gap * 0.6)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.gap

                        Glyph {
                            text: Theme.icons.wifi[Math.max(0, Math.min(4, net.modelData.bars))]
                            color: Theme.ink
                        }
                        Ink {
                            text: net.modelData.ssid
                            font.bold: net.modelData.connected
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(Theme.gap * 0.6)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(Theme.gap * 0.5)

                        Ink {
                            visible: net.modelData.known && !net.modelData.connected
                            text: "saved"
                            color: Theme.inkDim
                            font.pixelSize: Theme.small
                        }
                        Glyph {
                            visible: net.modelData.security !== "open"
                            text: Theme.icons.lock
                            color: Theme.inkDim
                            font.pixelSize: Theme.small
                        }
                        Glyph {
                            visible: net.modelData.connected
                            text: Theme.icons.check
                            color: Theme.ink
                        }
                    }

                    MouseArea {
                        id: netMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.join(net.modelData)
                    }
                }

                // Passphrase for a network iwd doesn't know yet.
                Row {
                    visible: root.asking === net.modelData.ssid
                    x: Math.round(Theme.gap * 0.6)
                    spacing: Theme.gap
                    onVisibleChanged: if (visible) passphrase.forceActiveFocus()

                    Rectangle {
                        width: root.contentWidth - joinButton.implicitWidth - Theme.gap * 2
                        height: joinButton.implicitHeight
                        radius: Math.round(Theme.radius * 0.6)
                        color: "#ffffff"
                        border.width: 1
                        border.color: Theme.rule

                        TextInput {
                            id: passphrase
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(Theme.gap * 0.6)
                            anchors.rightMargin: Math.round(Theme.gap * 0.6)
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            font.family: Theme.font
                            font.pixelSize: Theme.small
                            color: Theme.ink
                            clip: true
                            onAccepted: root.join(net.modelData)
                            Keys.onEscapePressed: root.asking = ""
                        }
                    }

                    TextButton {
                        id: joinButton
                        text: "Join"
                        strong: true
                        onClicked: root.join(net.modelData)
                    }
                }
            }
        }

        Ink {
            visible: !root.scanning && root.networks.length === 0
            text: "No networks found"
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
