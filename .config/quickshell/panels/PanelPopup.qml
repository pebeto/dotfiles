import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// A cream card that drops from a bar block and closes on Escape or on any
// click outside it, like a menu. `name` is its key in Panels. Content
// taller than the screen scrolls.
//
// It's a layer-shell window rather than an xdg popup: a popup can only grab
// input right after its parent window was clicked, so one opened from a key
// binding (`qs ipc call panel toggle bluetooth`) would fail. A transparent
// layer over the rest of the screen catches the outside clicks instead,
// including the one on the panel's own bar block.
Scope {
    id: root

    required property string name
    required property Item anchorItem
    required property var screen
    required property int maxHeight
    default property alias content: column.data
    property int contentWidth: Theme.panelWidth
    readonly property bool wanted: Panels.open === name && Panels.screen === screen.name
    // Distance from the screen's right edge to the block's, set on opening.
    // A hidden block (Bluetooth on a machine without a controller, opened
    // from a key binding) leaves the panel at the right edge.
    property int rightMargin: Theme.gap

    signal opened

    onWantedChanged: {
        if (!wanted)
            return;
        const p = anchorItem.mapToItem(null, anchorItem.width, 0);
        rightMargin = anchorItem.visible ? Math.max(Math.round(Theme.gap * 0.5), screen.width - Math.round(p.x)) : Math.round(Theme.gap * 0.5);
        opened();
    }

    PanelWindow {
        screen: root.screen
        visible: root.wanted
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-panel-shade"
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: Panels.close()
        }
    }

    PanelWindow {
        screen: root.screen
        visible: root.wanted
        anchors.top: true
        anchors.right: true
        margins.top: Math.round(Theme.gap * 0.5)
        margins.right: root.rightMargin
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"
        implicitWidth: card.width
        implicitHeight: card.height

        Rectangle {
            id: card

            width: root.contentWidth + Theme.gap * 4
            height: Math.min(column.implicitHeight + Theme.gap * 4, root.maxHeight)
            color: Theme.paper
            border.width: 1
            border.color: Theme.rule
            radius: Theme.radius
            focus: true
            Keys.onEscapePressed: Panels.close()

            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.gap * 2
                contentHeight: column.implicitHeight
                interactive: contentHeight > height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: column
                    width: root.contentWidth
                    spacing: Theme.gap * 1.5
                }
            }
        }
    }
}
