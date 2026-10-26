import QtQuick
import Quickshell
import qs
import qs.components
import qs.notifications
import qs.services

// The clock's panel: the date and a calendar, an agenda and the
// notification history. The agenda is today's, or the day clicked in the
// calendar's. Sound, what's playing and Syncthing are in the Control
// Center.
PanelPopup {
    id: root

    name: "clock"
    slideFrom: "right"
    // The day whose agenda shows, or null for today.
    property var day: null
    readonly property var picked: day ? Agenda.day(Qt.formatDate(day, "yyyy-MM-dd")) : null

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    onOpened: {
        calendar.reset();
        day = null;
        Agenda.invalidate();
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
        selected: root.day
        onPicked: d => {
            root.day = root.sameDay(d, clock.date) ? null : d;
            if (root.day)
                Agenda.loadMonth(d.getFullYear(), d.getMonth());
        }
    }

    Rule {}

    Column {
        width: root.contentWidth
        spacing: Theme.gap

        Item {
            width: parent.width
            height: todayButton.implicitHeight

            SectionTitle {
                anchors.verticalCenter: parent.verticalCenter
                text: root.day ? "Agenda · " + Qt.formatDate(root.day, "dddd d MMMM") : "Agenda"
            }
            TextButton {
                id: todayButton
                anchors.right: parent.right
                visible: root.day !== null
                text: "Today"
                onClicked: root.day = null
            }
        }
        AgendaView {
            width: parent.width
            groups: root.day ? root.picked?.groups ?? [] : Agenda.groups
            note: root.day ? (root.picked ? root.picked.note : "Loading…") : Agenda.note
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
