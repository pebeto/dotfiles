import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// The session menu (Super+Shift+e, `qs ipc call panel toggle session`):
// lock, suspend, log out, restart or shut down, in a card that fades and
// springs in like the launcher. Lock and suspend act at once; the other
// three ask first, on the same card. Arrows or Tab move, Enter picks, the
// underlined letter picks directly, Escape steps back or closes.
Scope {
    id: root

    readonly property bool wanted: Panels.open === "session"
    readonly property var screen: Quickshell.screens.find(s => s.name === Panels.screen) ?? Quickshell.screens[0]
    readonly property var actions: [
        { key: "l", label: "Lock", icon: Theme.icons.lock, ask: false, command: [Quickshell.env("HOME") + "/.config/sway/lock.sh"] },
        { key: "s", label: "Suspend", icon: Theme.icons.sleep, ask: false, command: ["systemctl", "suspend"] },
        { key: "o", label: "Log out", icon: Theme.icons.logout, ask: true, command: ["swaymsg", "exit"] },
        { key: "r", label: "Restart", icon: Theme.icons.restart, ask: true, command: ["systemctl", "reboot"] },
        { key: "d", label: "Shut down", icon: Theme.icons.power, ask: true, command: ["systemctl", "poweroff"] }
    ]
    property int current: 0
    // The action waiting for confirmation, or -1.
    property int confirming: -1
    readonly property int pad: Math.round(Theme.em * 2.5)
    property bool shown: false
    property bool up: false

    function pick(index) {
        const a = actions[index];
        if (a.ask && confirming !== index) {
            confirming = index;
            return;
        }
        Panels.close();
        Quickshell.execDetached(a.command);
    }

    onWantedChanged: {
        if (!wanted) {
            if (body.opacity === 0)
                shown = false;
            up = false;
            return;
        }
        current = 0;
        confirming = -1;
        shown = true;
        up = true;
        keys.forceActiveFocus();
    }

    // A transparent layer over the screen catches the click outside.
    PanelWindow {
        screen: root.screen
        visible: root.wanted
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-session-shade"
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: Panels.close()
        }
    }

    PanelWindow {
        screen: root.screen
        visible: root.shown
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-session"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"
        implicitWidth: card.width + root.pad * 2
        implicitHeight: card.height + root.pad * 2
        mask: Region {
            item: card
        }

        Item {
            id: body

            x: root.pad
            y: root.pad
            width: card.width
            height: card.height
            opacity: root.up ? 1 : 0
            scale: root.up ? 1 : 0.9

            Behavior on opacity {
                NumberAnimation {
                    duration: root.up ? 160 : 120
                    easing.type: root.up ? Easing.OutCubic : Easing.InCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.up ? 320 : 120
                    easing.type: root.up ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: 1.6
                }
            }
            onOpacityChanged: {
                if (opacity === 0 && !root.up)
                    root.shown = false;
            }

            RectangularShadow {
                anchors.fill: card
                radius: card.radius
                blur: Math.round(Theme.em * 1.6)
                offset.y: Math.round(Theme.em * 0.4)
                color: "#4d000000"
            }

            Rectangle {
                id: card

                width: buttons.implicitWidth + Theme.gap * 4
                height: buttons.implicitHeight + Theme.gap * 4
                radius: Theme.radius * 2
                color: Theme.paper
                border.width: 1
                border.color: Theme.rule

                Item {
                    id: keys

                    focus: true
                    Keys.onPressed: e => {
                        const n = root.actions.length;
                        if (e.key === Qt.Key_Escape) {
                            if (root.confirming >= 0)
                                root.confirming = -1;
                            else
                                Panels.close();
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                            root.pick(root.confirming >= 0 ? root.confirming : root.current);
                        } else if (root.confirming >= 0) {
                            return;
                        } else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) {
                            root.current = (root.current + 1) % n;
                        } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) {
                            root.current = (root.current + n - 1) % n;
                        } else {
                            const i = root.actions.findIndex(a => a.key === e.text.toLowerCase());
                            if (i < 0)
                                return;
                            root.current = i;
                            root.pick(i);
                        }
                        e.accepted = true;
                    }
                }

                // The buttons, or the question in their place, at the same
                // size so the card doesn't jump.
                Item {
                    x: Theme.gap * 2
                    y: Theme.gap * 2
                    width: buttons.implicitWidth
                    height: buttons.implicitHeight

                    Row {
                        id: buttons

                        visible: root.confirming < 0
                        spacing: Theme.gap

                        Repeater {
                            model: root.actions

                            Rectangle {
                                id: button

                                required property var modelData
                                required property int index

                                width: Math.round(Theme.em * 5)
                                height: Math.round(Theme.em * 5)
                                radius: Theme.radius * 1.5
                                color: index === root.current ? Theme.highlight : mouse.containsMouse ? Theme.paperHover : "transparent"

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Math.round(Theme.gap * 0.6)

                                    Glyph {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: button.modelData.icon
                                        color: Theme.ink
                                        font.pixelSize: Math.round(Theme.em * 1.8)
                                    }
                                    // The letter that picks it, underlined.
                                    Ink {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        textFormat: Text.StyledText
                                        font.pixelSize: Theme.small
                                        text: {
                                            const l = button.modelData.label;
                                            const at = l.toLowerCase().indexOf(button.modelData.key);
                                            return l.slice(0, at) + "<u>" + l[at] + "</u>" + l.slice(at + 1);
                                        }
                                    }
                                }

                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.current = button.index;
                                        root.pick(button.index);
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: root.confirming >= 0
                        spacing: Theme.gap * 1.5

                        Ink {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.confirming >= 0 ? root.actions[root.confirming].label + " now?" : ""
                            font.bold: true
                            font.pixelSize: Math.round(Theme.em * 1.2)
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Theme.gap

                            TextButton {
                                text: "Cancel"
                                onClicked: root.confirming = -1
                            }
                            TextButton {
                                text: root.confirming >= 0 ? root.actions[root.confirming].label : ""
                                strong: true
                                onClicked: root.pick(root.confirming)
                            }
                        }
                    }
                }
            }
        }
    }
}
