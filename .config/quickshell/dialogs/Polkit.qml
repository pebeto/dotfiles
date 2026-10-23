import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs
import qs.components

// The password prompt for anything that asks polkit for admin rights, such
// as starting bluetoothd from the Bluetooth panel. Quickshell registers as
// the session's polkit agent; with no agent those requests fail without
// asking. Enter submits, Escape cancels.
Scope {
    id: root

    readonly property var flow: agent.flow

    function submit() {
        if (!flow?.isResponseRequired)
            return;
        flow.submit(input.text);
        input.text = "";
    }

    function cancel() {
        input.text = "";
        flow?.cancelAuthenticationRequest();
    }

    PolkitAgent {
        id: agent
    }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: agent.isActive && root.flow !== null
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-polkit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "#66000000"
        onVisibleChanged: {
            if (visible) {
                input.forceActiveFocus();
                appear.restart();
            }
        }

        Rectangle {
            id: card

            anchors.centerIn: parent
            // Fades and grows in a little when a request arrives.
            opacity: 0
            scale: 0.96

            ParallelAnimation {
                id: appear

                NumberAnimation {
                    target: card
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 160
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: card
                    property: "scale"
                    from: 0.96
                    to: 1
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
            width: Math.round(Theme.em * 24)
            height: column.implicitHeight + Theme.gap * 4
            radius: Theme.radius
            color: Theme.paperGlass
            border.width: 1
            border.color: Theme.rule

            Column {
                id: column

                x: Theme.gap * 2
                y: Theme.gap * 2
                width: card.width - Theme.gap * 4
                spacing: Theme.gap

                Row {
                    spacing: Theme.gap

                    Glyph {
                        text: Theme.icons.lock
                        color: Theme.ink
                    }
                    Ink {
                        text: "Authentication required"
                        font.bold: true
                    }
                }
                Ink {
                    width: parent.width
                    text: root.flow?.message ?? ""
                    wrapMode: Text.Wrap
                }
                Ink {
                    width: parent.width
                    visible: text !== ""
                    text: root.flow?.supplementaryMessage ?? ""
                    color: root.flow?.supplementaryIsError ? Theme.critical : Theme.inkDim
                    font.pixelSize: Theme.small
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    width: parent.width
                    height: Math.round(Theme.em * 2)
                    radius: Math.round(Theme.radius * 0.6)
                    color: "#ffffff"
                    border.width: 1
                    border.color: input.activeFocus ? Theme.link : Theme.rule

                    Ink {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.gap
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: (root.flow?.inputPrompt ?? "Password").replace(/:\s*$/, "")
                        color: Theme.inkDim
                    }
                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: Theme.gap
                        anchors.rightMargin: Theme.gap
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.font
                        font.pixelSize: Theme.em
                        color: Theme.ink
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        enabled: root.flow?.isResponseRequired ?? false
                        clip: true
                        onAccepted: root.submit()
                        Keys.onEscapePressed: root.cancel()
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: Theme.gap

                    TextButton {
                        text: "Cancel"
                        onClicked: root.cancel()
                    }
                    TextButton {
                        text: "Authenticate"
                        strong: true
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
