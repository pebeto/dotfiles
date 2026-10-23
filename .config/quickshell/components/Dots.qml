import QtQuick
import qs

// Three dots pulsing in turn, like a typing indicator.
Row {
    id: dots

    property bool animating: false

    spacing: Math.round(Theme.em * 0.25)

    Repeater {
        model: 3

        Rectangle {
            id: dot

            required property int index

            width: Math.round(Theme.em * 0.35)
            height: width
            radius: width / 2
            color: Theme.inkDim
            opacity: 0.3

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: dots.animating

                PauseAnimation {
                    duration: dot.index * 160
                }
                NumberAnimation {
                    to: 1
                    duration: 320
                }
                NumberAnimation {
                    to: 0.3
                    duration: 320
                }
                PauseAnimation {
                    duration: (2 - dot.index) * 160
                }
            }
        }
    }
}
