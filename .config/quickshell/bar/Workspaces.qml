import QtQuick
import Quickshell
import Quickshell.I3
import qs
import qs.components
import qs.services

// Workspace buttons for one output, plus the binding-mode tag ("resize").
// Scrolling over them steps through workspaces, as swaybar's did.
Row {
    id: root

    required property var screen
    // Matched by output name: I3.monitorFor() is a plain call, so a binding
    // on it would stay null if it ran before the first IPC reply. The screen
    // itself goes null for a moment while outputs come and go (a VT switch).
    readonly property var workspaces: I3.workspaces.values.filter(w => w.monitor?.name === screen?.name).sort((a, b) => a.number - b.number)
    // Touchpads send many small deltas, so steps are counted per 120 units
    // (one mouse-wheel notch).
    property real wheelAcc: 0

    function scroll(e) {
        wheelAcc += e.angleDelta.y;
        const steps = Math.trunc(wheelAcc / 120);
        if (steps === 0)
            return;
        wheelAcc -= steps * 120;
        I3.dispatch(steps > 0 ? "workspace prev_on_output" : "workspace next_on_output");
    }

    height: Theme.barHeight
    spacing: 0

    Repeater {
        model: ScriptModel {
            values: root.workspaces
        }

        Item {
            id: button

            required property var modelData
            readonly property var ws: modelData
            // From Sway, not ws.focused, which Quickshell works out from
            // its focused output (see services/Sway.qml).
            readonly property bool focused: ws.name === Sway.focusedWorkspace

            width: Math.max(Theme.barHeight, label.implicitWidth + Theme.gap * 2)
            height: Theme.barHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.round(Theme.em * 0.15)
                radius: Math.round(Theme.radius * 0.6)
                color: button.focused ? Theme.accent : button.ws.urgent ? Theme.urgent : mouse.containsMouse ? Theme.hover : "transparent"
                // Shown on another output, but not the focused one.
                border.width: button.ws.active && !button.focused ? 1 : 0
                border.color: Theme.accent
            }

            Txt {
                id: label
                anchors.centerIn: parent
                text: button.ws.name
                color: button.focused ? Theme.accentFg : Theme.fg
                font.bold: button.focused
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: button.ws.activate()
                onWheel: e => root.scroll(e)
            }
        }
    }

    Item {
        visible: Sway.mode !== "default"
        width: modeLabel.implicitWidth + Theme.gap * 2
        height: Theme.barHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.round(Theme.em * 0.15)
            radius: Math.round(Theme.radius * 0.6)
            color: Theme.urgent
        }

        Txt {
            id: modeLabel
            anchors.centerIn: parent
            text: Sway.mode
            font.bold: true
        }
    }
}
