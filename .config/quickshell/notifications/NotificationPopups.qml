import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// The notification popups, stacked under the bar at the top right of the
// focused output, newest on top. Only the cards take input; the gaps
// between them click through.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Sway.focusedOutput) ?? Quickshell.screens[0]
    visible: Notifs.popups.length > 0
    anchors.top: true
    anchors.right: true
    margins.top: Theme.gap
    margins.right: Theme.gap
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-notifications"
    color: "transparent"
    implicitWidth: Theme.notifWidth
    implicitHeight: Math.max(1, column.implicitHeight)
    mask: Region {
        item: column
    }

    Column {
        id: column
        // The popups already showing glide down to make room for a new one.
        move: Transition {
            NumberAnimation {
                property: "y"
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        width: parent.width
        spacing: Theme.gap

        Repeater {
            model: ScriptModel {
                values: Notifs.popups.slice(0, 6)
            }

            NotificationCard {
                required property var modelData
                entry: modelData
                width: column.width
            }
        }
    }
}
