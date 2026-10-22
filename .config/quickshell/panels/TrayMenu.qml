import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// A tray app's menu (Tray.menuItem), drawn like the bar's other panels. An
// entry with a submenu opens it in place, with a row on top to go back.
PanelPopup {
    id: root

    // Submenus opened so far; the last one is showing.
    property var trail: []
    readonly property var menu: trail.length > 0 ? trail[trail.length - 1] : Tray.menuItem?.menu ?? null
    readonly property var labels: opener.children.values.filter(e => !e.isSeparator).map(e => plain(e.text))
    // The column for check marks (and the Back arrow), only when it's used.
    readonly property int textX: trail.length > 0 || opener.children.values.some(e => e.buttonType !== QsMenuButtonType.None) ? Math.round(Theme.em * 1.5) : Math.round(Theme.gap * 0.6)

    // DBusMenu marks access keys with "_" and writes a literal one as "__".
    function plain(text) {
        return text.replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_");
    }

    name: "tray"
    // Wide enough for the longest entry, plus the check and arrow columns.
    contentWidth: Math.min(Theme.panelWidth, Math.max(Math.round(Theme.em * 9), Math.ceil(widest.width) + Theme.em * 3))
    onOpened: trail = []
    // The app quit, or dropped its menu, while it was open.
    onMenuChanged: {
        if (menu === null && Panels.open === name)
            Panels.close();
    }

    TextMetrics {
        id: widest
        font.family: Theme.font
        font.pixelSize: Theme.em
        // JuliaMono is monospaced, so the longest label is also the widest.
        text: root.labels.reduce((a, b) => b.length > a.length ? b : a, "")
    }

    QsMenuOpener {
        id: opener
        menu: root.menu
    }

    Column {
        width: root.contentWidth

        Entry {
            visible: root.trail.length > 0
            label: "Back"
            leading: Theme.icons.left
            onActivated: root.trail = root.trail.slice(0, -1)
        }
        Rule {
            visible: root.trail.length > 0
        }

        Repeater {
            model: opener.children

            Item {
                id: slot

                required property QsMenuEntry modelData

                width: root.contentWidth
                height: modelData.isSeparator ? Math.round(Theme.gap * 1.2) : entry.height

                Rule {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: slot.modelData.isSeparator
                }

                Entry {
                    id: entry

                    visible: !slot.modelData.isSeparator
                    label: root.plain(slot.modelData.text)
                    icon: slot.modelData.icon
                    leading: slot.modelData.buttonType !== QsMenuButtonType.None && slot.modelData.checkState === Qt.Checked ? Theme.icons.check : ""
                    submenu: slot.modelData.hasChildren
                    enabled: slot.modelData.enabled
                    onActivated: {
                        if (slot.modelData.hasChildren) {
                            root.trail = [...root.trail, slot.modelData];
                        } else {
                            slot.modelData.triggered();
                            Panels.close();
                        }
                    }
                }
            }
        }
    }

    component Entry: Rectangle {
        id: entryRow

        property string label
        property string icon
        property string leading
        property bool submenu: false

        signal activated

        width: root.contentWidth
        height: Math.round(Theme.em * 1.7)
        radius: Math.round(Theme.radius * 0.6)
        color: enabled && mouse.containsMouse ? Theme.highlight : "transparent"

        Glyph {
            x: Math.round(Theme.gap * 0.4)
            anchors.verticalCenter: parent.verticalCenter
            text: entryRow.leading
            color: Theme.ink
        }
        IconImage {
            id: iconImage
            x: root.textX
            anchors.verticalCenter: parent.verticalCenter
            visible: entryRow.icon !== ""
            source: entryRow.icon
            implicitSize: Theme.em
        }
        Ink {
            anchors.left: parent.left
            anchors.leftMargin: root.textX + (iconImage.visible ? Theme.em + Math.round(Theme.gap * 0.6) : 0)
            anchors.right: arrow.left
            anchors.verticalCenter: parent.verticalCenter
            text: entryRow.label
            color: entryRow.enabled ? Theme.ink : Theme.inkDim
            elide: Text.ElideRight
        }
        Glyph {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: Math.round(Theme.gap * 0.4)
            anchors.verticalCenter: parent.verticalCenter
            text: entryRow.submenu ? Theme.icons.right : ""
            color: Theme.inkDim
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: entryRow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (entryRow.enabled)
                    entryRow.activated();
            }
        }
    }
}
