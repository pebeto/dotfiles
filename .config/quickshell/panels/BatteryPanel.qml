import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// The battery panel (T470), from the bar's battery block: each pack's
// charge and wear, how long the internal pack lasts on its own, the last 24
// hours, the power mode and the charge limit (services/Battery.qml).
PanelPopup {
    id: root

    function duration(hours) {
        const m = Math.round(hours * 60);
        return m < 60 ? m + " min" : Math.floor(m / 60) + " h" + (m % 60 ? " " + m % 60 + " min" : "");
    }

    readonly property string watts: isNaN(Battery.rate) || Battery.rate < 0.1 ? "" : "  ·  " + Battery.rate.toFixed(1) + " W"
    readonly property string summary: {
        if (Battery.charging)
            return "Charging" + watts + (isNaN(Battery.timeLeft) ? "" : "  ·  " + (Battery.limited ? Battery.stop + "%" : "full") + " in " + duration(Battery.timeLeft));
        if (Battery.discharging)
            return "On battery" + watts + (isNaN(Battery.timeLeft) ? "" : "  ·  " + duration(Battery.timeLeft) + " left");
        if (Battery.packs.every(p => p.status === "Full"))
            return "Plugged in  ·  full";
        return Battery.limited ? "Plugged in  ·  held at " + Battery.stop + "%" : "Plugged in";
    }

    name: "battery"
    onOpened: Battery.refresh()

    Column {
        width: root.contentWidth
        spacing: 2

        Ink {
            text: "Battery"
            font.bold: true
            font.pixelSize: Math.round(Theme.em * 1.15)
        }
        Ink {
            text: root.summary
            color: Battery.charging ? Theme.good : Theme.inkDim
        }
    }

    Column {
        width: root.contentWidth
        spacing: Theme.gap

        SectionTitle {
            text: "Packs"
        }

        Repeater {
            model: Battery.packs

            Column {
                id: pack

                required property var modelData
                readonly property real health: modelData.full / modelData.design * 100
                readonly property string doing: ({ Charging: "charging", Discharging: "in use", Full: "full" })[modelData.status] ?? "idle"

                width: root.contentWidth
                spacing: 2

                Item {
                    width: parent.width
                    height: Math.round(Theme.em * 1.2)

                    Ink {
                        id: packName
                        width: Math.round(Theme.em * 5)
                        anchors.verticalCenter: parent.verticalCenter
                        text: ({ BAT0: "Internal", BAT1: "External" })[pack.modelData.name] ?? pack.modelData.name
                    }
                    Ink {
                        id: percent
                        width: Math.round(Theme.em * 3)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: pack.modelData.capacity + "%"
                    }
                    Rectangle {
                        id: track
                        anchors.left: packName.right
                        anchors.leftMargin: Theme.gap
                        anchors.right: percent.left
                        anchors.rightMargin: Theme.gap
                        anchors.verticalCenter: parent.verticalCenter
                        height: Math.max(4, Math.round(Theme.em * 0.4))
                        radius: height / 2
                        color: Theme.rule
                        opacity: 0.5
                    }
                    Rectangle {
                        anchors.left: track.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: track.width * Math.min(1, pack.modelData.capacity / 100)
                        height: track.height
                        radius: height / 2
                        color: pack.modelData.status === "Charging" ? Theme.good : pack.modelData.capacity <= Battery.partnerLow ? Theme.critical : Theme.accent
                    }
                    // Where the charge limit stops it.
                    Rectangle {
                        visible: pack.modelData.stop < 100
                        x: Math.round(track.x + track.width * pack.modelData.stop / 100) - 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: track.height + 6
                        color: Theme.ink
                    }
                }
                Ink {
                    x: packName.width + Theme.gap
                    text: [pack.doing, pack.health > 0 ? "health " + Math.round(pack.health) + "%" : "", pack.modelData.cycles > 0 ? pack.modelData.cycles + " cycles" : ""].filter(s => s).join("  ·  ")
                    color: Theme.inkDim
                    font.pixelSize: Theme.small
                }
            }
        }

        Ink {
            visible: !isNaN(Battery.internalAlone)
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Pull the external pack now and the internal one lasts about " + root.duration(Battery.internalAlone) + "."
            color: Theme.inkDim
            font.pixelSize: Theme.small
        }
    }

    Column {
        width: root.contentWidth
        spacing: Math.round(Theme.gap * 0.5)

        SectionTitle {
            text: "Last 24 hours"
        }

        Item {
            id: chart

            readonly property real slot: width / Math.max(1, Battery.history.length)

            visible: Battery.history.some(s => s)
            width: parent.width
            height: Math.round(Theme.em * 4)

            // 100% and 50%.
            Rule {
                y: 0
            }
            Rule {
                y: Math.round(chart.height / 2)
            }
            Rectangle {
                y: chart.height - 1
                width: parent.width
                height: 1
                color: Theme.rule
            }
            Repeater {
                model: Battery.history

                Rectangle {
                    required property var modelData
                    required property int index

                    visible: modelData !== null
                    x: Math.round(index * chart.slot)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    width: Math.max(1, Math.round(chart.slot) - 1)
                    height: Math.max(1, Math.round((chart.height - 1) * (modelData?.level ?? 0) / 100))
                    color: modelData?.state === "c" ? Theme.good : modelData?.state === "a" ? Theme.olive : Theme.accent
                }
            }
        }

        Item {
            visible: chart.visible
            width: parent.width
            height: ago.implicitHeight

            Ink {
                id: ago
                text: "24 h ago"
                color: Theme.inkDim
                font.pixelSize: Theme.small
            }
            Ink {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "12 h ago"
                color: Theme.inkDim
                font.pixelSize: Theme.small
            }
            Ink {
                anchors.right: parent.right
                text: "now"
                color: Theme.inkDim
                font.pixelSize: Theme.small
            }
        }

        Row {
            visible: chart.visible
            spacing: Theme.gap

            Repeater {
                model: [
                    { color: Theme.accent, label: "on battery" },
                    { color: Theme.good, label: "charging" },
                    { color: Theme.olive, label: "plugged in" }
                ]

                Row {
                    required property var modelData

                    spacing: Math.round(Theme.gap * 0.5)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(Theme.em * 0.6)
                        height: width
                        radius: 2
                        color: parent.modelData.color
                    }
                    Ink {
                        text: parent.modelData.label
                        color: Theme.inkDim
                        font.pixelSize: Theme.small
                    }
                }
            }
        }

        Ink {
            visible: !chart.visible
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Nothing recorded yet. The battery-notify timer takes a reading every two minutes."
            color: Theme.inkDim
            font.pixelSize: Theme.small
        }
    }

    Loader {
        active: Battery.profiles
        visible: active
        width: root.contentWidth
        sourceComponent: Component {
            PowerModeView {}
        }
    }

    Column {
        visible: Battery.limitSupported
        width: root.contentWidth
        spacing: Math.round(Theme.gap * 0.5)

        SectionTitle {
            text: "Charge limit"
        }

        Item {
            width: parent.width
            height: limitButton.implicitHeight

            Ink {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.fullOnce ? "Charging to 100% once" : Battery.limited ? "Stops at " + Battery.stop + "%" : "Charges to 100%"
            }
            TextButton {
                id: limitButton
                anchors.right: parent.right
                visible: Battery.limitWritable
                text: Battery.fullOnce ? "Cancel" : Battery.limited ? "Turn off" : "Turn on"
                onClicked: Battery.setLimit(Battery.fullOnce || !Battery.limited)
            }
        }

        Ink {
            width: parent.width
            wrapMode: Text.WordWrap
            text: !Battery.limitWritable ? "Changing it needs the udev rule that install.sh prints."
                : Battery.fullOnce ? "Back to " + Battery.careStop + "% once both packs are full."
                : Battery.limited ? "Keeps the packs from sitting full while plugged in, which wears them out sooner."
                : "Turn it on to stop at " + Battery.careStop + "% while plugged in."
            color: Theme.inkDim
            font.pixelSize: Theme.small
        }

        TextButton {
            visible: Battery.limitWritable && Battery.limited && !Battery.fullOnce
            text: "Charge to full once"
            onClicked: Battery.chargeFullOnce()
        }
    }
}
