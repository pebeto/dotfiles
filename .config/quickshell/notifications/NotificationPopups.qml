import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import qs
import qs.services

// The notification popups, stacked under the bar at the top right of the
// focused output, newest on top. Only the cards take input; the gaps
// between them click through.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) ?? Quickshell.screens[0]
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
