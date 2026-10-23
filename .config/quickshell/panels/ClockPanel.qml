import QtQuick
import Quickshell
import qs
import qs.components
import qs.notifications
import qs.services

// The clock's panel: the date and a calendar, today's agenda, what's
// playing, the sound output, Syncthing's state, and the notification
// history.
PanelPopup {
    id: root

    name: "clock"
    slideFrom: "right"
    onOpened: {
        calendar.reset();
        Syncthing.update();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        width: root.contentWidth
        spacing: 2

        Ink {
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
            font.bold: true
            font.pixelSize: Math.round(Theme.em * 1.15)
        }
        Ink {
            text: Qt.formatDateTime(clock.date, "HH:mm") + (Notifs.dnd ? "  ·  focus mode on" : "")
            color: Theme.inkDim
        }
    }

    Calendar {
        id: calendar
        width: root.contentWidth
        today: clock.date
    }

    Rule {}

    Column {
        width: root.contentWidth
        spacing: Theme.gap

        SectionTitle {
            text: "Agenda"
        }
        AgendaView {
            width: parent.width
        }
    }

    // Only while some player has something loaded.
    Rule {
        visible: media.player !== null
    }

    Column {
        visible: media.player !== null
        width: root.contentWidth
        spacing: Theme.gap

        SectionTitle {
            text: "Now playing"
        }
        MediaView {
            id: media
            width: parent.width
        }
    }

    Rule {}

    Column {
        width: root.contentWidth
        spacing: Theme.gap

        SectionTitle {
            text: "Sound"
        }
        SoundView {
            width: parent.width
        }

        Row {
            spacing: Theme.gap
            topPadding: Math.round(Theme.gap * 0.5)

            Glyph {
                text: Theme.icons.sync
                color: Theme.ink
            }
            Ink {
                text: "Syncthing"
            }
            Ink {
                text: Syncthing.state === "synced" ? "up to date" : Syncthing.state === "syncing" ? "syncing " + Syncthing.percent + "%" : "offline"
                color: Syncthing.state === "synced" ? Theme.good : Syncthing.state === "syncing" ? Theme.olive : Theme.inkDim
            }
        }
    }

    Rule {}

    Column {
        width: root.contentWidth
        spacing: Math.round(Theme.gap * 0.5)

        Item {
            width: parent.width
            height: clearButton.implicitHeight

            SectionTitle {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
            }
            TextButton {
                id: clearButton
                anchors.right: parent.right
                visible: Notifs.history.length > 0
                text: "Clear"
                onClicked: Notifs.clearHistory()
            }
        }

        Repeater {
            model: ScriptModel {
                values: Notifs.history
            }

            NotificationCard {
                required property var modelData
                entry: modelData
                popup: false
                width: root.contentWidth
            }
        }

        Ink {
            visible: Notifs.history.length === 0
            text: "Nothing recent"
            color: Theme.inkDim
        }
    }
}
