import QtQuick
import QtQuick.Effects
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
//
// The card drops down from under the bar, or with `slideFrom: "right"`
// (the clock panel) slides in from the right edge of the screen. Dropping,
// it moves inside a window that stays put and clips it at the bar's edge,
// so it draws its own shadow. Sliding, the whole window moves (its right
// margin animates), so swayfx's shadow and corners stay on the card.
Scope {
    id: root

    required property string name
    required property Item anchorItem
    required property var screen
    required property int maxHeight
    default property alias content: column.data
    property int contentWidth: Theme.panelWidth
    // "top" or "right".
    property string slideFrom: "top"
    readonly property bool drops: slideFrom === "top"
    // The dropping card's room for its shadow, and its gap below the bar.
    readonly property int pad: 32
    readonly property int top: Math.round(Theme.gap * 0.5)
    readonly property bool wanted: Panels.open === name && Panels.screen === screen.name
    // Distance from the screen's right edge to the block's, set on opening.
    // A hidden block (Bluetooth on a machine without a controller, opened
    // from a key binding) leaves the panel at the right edge.
    property int rightMargin: Theme.gap
    // 0 is in place, 1 is just out of sight. The card stays mapped until
    // the closing slide is done.
    property real slide: 1
    property bool shown: false

    signal opened

    onWantedChanged: {
        if (!wanted) {
            slideIn.stop();
            slideOut.start();
            return;
        }
        const p = anchorItem.mapToItem(null, anchorItem.width, 0);
        rightMargin = anchorItem.visible ? Math.max(Math.round(Theme.gap * 0.5), screen.width - Math.round(p.x)) : Math.round(Theme.gap * 0.5);
        opened();
        slideOut.stop();
        shown = true;
        slideIn.start();
    }

    NumberAnimation {
        id: slideIn
        target: root
        property: "slide"
        to: 0
        duration: 220
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: slideOut
        target: root
        property: "slide"
        to: 1
        duration: 160
        easing.type: Easing.InCubic
        onFinished: {
            if (!root.wanted)
                root.shown = false;
        }
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
        visible: root.shown
        anchors.top: true
        anchors.right: true
        margins.top: root.drops ? 0 : root.top
        margins.right: root.drops ? root.rightMargin - root.pad : Math.round(root.rightMargin - root.slide * (card.width + root.rightMargin))
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: root.drops ? "quickshell-dropdown" : "quickshell-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"
        implicitWidth: card.width + (root.drops ? root.pad * 2 : 0)
        implicitHeight: card.height + (root.drops ? root.top + root.pad : 0)
        mask: Region {
            item: card
        }

        // The same shadow swayfx gives the clock panel (shadow_blur_radius
        // and shadow_color in sway/config).
        RectangularShadow {
            visible: root.drops
            anchors.fill: card
            radius: card.radius
            blur: 20
            color: "#66000000"
        }

        Rectangle {
            id: card

            x: root.drops ? root.pad : 0
            y: root.drops ? Math.round(root.top - root.slide * (root.top + height + root.pad)) : 0
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
