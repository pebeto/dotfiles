import QtQuick
import qs
import qs.components

// A month grid with today marked, starting on Sunday like `cal`. The arrows
// or the wheel change month; clicking the title goes back to this one.
Column {
    id: root

    required property date today
    property int year: today.getFullYear()
    property int month: today.getMonth()
    readonly property int firstWeekday: new Date(year, month, 1).getDay()
    readonly property int days: new Date(year, month + 1, 0).getDate()
    readonly property int rows: Math.ceil((firstWeekday + days) / 7)
    readonly property real cell: width / 7

    function reset() {
        year = today.getFullYear();
        month = today.getMonth();
    }

    function shift(by) {
        const m = month + by;
        year += Math.floor(m / 12);
        month = ((m % 12) + 12) % 12;
    }

    spacing: Math.round(Theme.gap * 0.6)

    Item {
        width: parent.width
        height: title.implicitHeight

        Glyph {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.icons.left
            color: prevMouse.containsMouse ? Theme.ink : Theme.inkDim
            MouseArea {
                id: prevMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.shift(-1)
            }
        }

        Ink {
            id: title
            anchors.centerIn: parent
            text: Qt.locale("en_US").standaloneMonthName(root.month) + " " + root.year
            font.bold: true
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reset()
            }
        }

        Glyph {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.icons.right
            color: nextMouse.containsMouse ? Theme.ink : Theme.inkDim
            MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.shift(1)
            }
        }
    }

    Grid {
        columns: 7

        Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

            Ink {
                required property string modelData
                width: root.cell
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.inkDim
                font.pixelSize: Theme.small
            }
        }

        Repeater {
            model: root.rows * 7

            Item {
                id: day

                required property int index
                readonly property int date: index - root.firstWeekday + 1
                readonly property bool inMonth: date >= 1 && date <= root.days
                readonly property bool isToday: inMonth && date === root.today.getDate() && root.month === root.today.getMonth() && root.year === root.today.getFullYear()

                width: root.cell
                height: Math.round(Theme.em * 1.6)

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.height - 2
                    height: width
                    radius: width / 2
                    color: day.isToday ? Theme.accent : "transparent"
                }

                Ink {
                    anchors.centerIn: parent
                    visible: day.inMonth
                    text: day.date
                    font.bold: day.isToday
                }
            }
        }
    }

    WheelHandler {
        onWheel: e => root.shift(e.angleDelta.y > 0 ? -1 : 1)
    }
}
