import QtQuick
import Quickshell.Services.UPower
import qs
import qs.components

// power-profiles-daemon's modes, as tiles on the battery panel. Performance
// only shows on a machine that has it, and a line says when the daemon
// holds it back.
Column {
    id: root

    readonly property var modes: [
        { profile: PowerProfile.PowerSaver, label: "Saver", icon: Theme.icons.leaf },
        { profile: PowerProfile.Balanced, label: "Balanced", icon: Theme.icons.balance },
        { profile: PowerProfile.Performance, label: "Performance", icon: Theme.icons.speed }
    ].filter(m => m.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)

    spacing: Theme.gap

    SectionTitle {
        text: "Power mode"
    }

    Row {
        spacing: Theme.gap

        Repeater {
            model: root.modes

            Tile {
                required property var modelData

                width: Math.floor((root.width - Theme.gap * (root.modes.length - 1)) / root.modes.length)
                height: Math.round(Theme.em * 3.4)
                icon: modelData.icon
                label: modelData.label
                on: PowerProfiles.profile === modelData.profile
                onClicked: PowerProfiles.profile = modelData.profile
            }
        }
    }

    Ink {
        visible: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
        width: root.width
        wrapMode: Text.WordWrap
        text: "Performance is held back: " + (PowerProfiles.degradationReason === PerformanceDegradationReason.LapDetected ? "the laptop is on a lap." : "it's running hot.")
        color: Theme.inkDim
        font.pixelSize: Theme.small
    }
}
