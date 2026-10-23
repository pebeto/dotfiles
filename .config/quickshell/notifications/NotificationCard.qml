import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// One notification, as a popup (`popup: true`) or as a row in the clock
// panel's history. On a popup, left click closes it, middle click runs its
// default action, and right click closes them all. In
// the history a click runs the default action and the × forgets it.
Rectangle {
    id: root

    required property var entry
    property bool popup: true
    readonly property bool critical: entry.urgency === NotificationUrgency.Critical
    readonly property bool low: entry.urgency === NotificationUrgency.Low
    readonly property var actions: (entry.n?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property bool hasDefault: (entry.n?.actions ?? []).some(a => a.identifier === "default")
    readonly property int pad: popup ? Theme.gap * 1.5 : Math.round(Theme.gap * 0.6)

    function ago(time) {
        const s = (clock.date - time) / 1000;
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + "m";
        if (s < 86400)
            return Math.floor(s / 3600) + "h";
        return Qt.formatDateTime(time, "ddd HH:mm");
    }

    implicitHeight: content.implicitHeight + pad * 2
    // A popup slides in from the right as it arrives.
    transform: Translate {
        id: arrival
    }

    NumberAnimation {
        running: root.popup
        target: arrival
        property: "x"
        from: Theme.notifWidth
        to: 0
        duration: 220
        easing.type: Easing.OutCubic
    }
    color: popup ? Theme.paper : mouse.containsMouse ? Theme.paperHover : "transparent"
    border.width: popup ? 1 : 0
    border.color: critical ? Theme.critical : Theme.rule
    radius: Math.round(Theme.radius * 0.6)

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: root.popup || root.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
        onContainsMouseChanged: if (root.popup) root.entry.hovered = containsMouse
        onClicked: e => {
            if (!root.popup) {
                if (root.hasDefault)
                    Notifs.invoke(root.entry, "default");
            } else if (e.button === Qt.LeftButton) {
                Notifs.dismiss(root.entry);
            } else if (e.button === Qt.MiddleButton) {
                Notifs.invoke(root.entry, "default");
            } else {
                Notifs.dismissAll();
            }
        }
    }

    Row {
        id: content

        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        spacing: Theme.gap

        Rectangle {
            visible: root.entry.missed && !root.popup
            width: Math.round(Theme.em * 0.3)
            height: width
            radius: width / 2
            color: Theme.accent
            anchors.verticalCenter: parent.verticalCenter
        }

        IconImage {
            id: icon
            visible: root.entry.icon !== "" && status !== Image.Error
            source: root.entry.icon
            implicitSize: root.popup ? Math.round(Theme.em * 2.4) : Math.round(Theme.em * 1.4)
        }

        Column {
            width: content.width - (icon.visible ? icon.width + content.spacing : 0) - (root.entry.missed && !root.popup ? Math.round(Theme.em * 0.3) + content.spacing : 0)
            spacing: Math.round(Theme.gap * 0.3)

            Item {
                width: parent.width
                height: appName.implicitHeight

                Ink {
                    id: appName
                    width: parent.width - when.implicitWidth - closeGlyph.width - Theme.gap
                    elide: Text.ElideRight
                    text: root.entry.app
                    color: Theme.good
                    font.pixelSize: Theme.small
                }

                Ink {
                    id: when
                    anchors.right: closeGlyph.left
                    anchors.rightMargin: Math.round(Theme.gap * 0.5)
                    text: root.ago(root.entry.time)
                    color: Theme.inkDim
                    font.pixelSize: Theme.small
                }

                Glyph {
                    id: closeGlyph
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.icons.close
                    font.pixelSize: Theme.small
                    color: closeMouse.containsMouse ? Theme.critical : Theme.inkDim
                    opacity: mouse.containsMouse || closeMouse.containsMouse ? 1 : 0

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.popup ? Notifs.dismiss(root.entry) : Notifs.forget(root.entry)
                    }
                }
            }

            Ink {
                width: parent.width
                text: root.entry.summary
                textFormat: Text.PlainText
                font.bold: true
                color: root.critical ? Theme.critical : root.low ? Theme.inkDim : Theme.ink
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Ink {
                width: parent.width
                visible: text !== ""
                text: root.entry.body
                textFormat: Text.StyledText
                color: root.low ? Theme.inkDim : Theme.ink
                linkColor: Theme.link
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 6 : 2
                elide: Text.ElideRight
                font.pixelSize: root.popup ? Theme.em : Theme.small
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                width: parent.width
                visible: root.popup && root.actions.length > 0
                spacing: Math.round(Theme.gap * 0.5)
                topPadding: Math.round(Theme.gap * 0.4)

                Repeater {
                    model: root.actions

                    TextButton {
                        required property var modelData
                        text: modelData.text
                        strong: true
                        onClicked: Notifs.invoke(root.entry, modelData.identifier)
                    }
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
