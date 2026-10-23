import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// The local LLM server's panel (workstation): what's running and how busy
// it is, the GPU's memory, and the configured models to start, stop or
// switch to (services/Llm.qml).
PanelPopup {
    id: root

    readonly property real usedGiB: System.gpuMemUsed / 1024
    readonly property real totalGiB: System.gpuMemTotal / 1024

    name: "llm"
    onOpened: Llm.poll()

    Column {
        width: root.contentWidth
        spacing: 2

        Ink {
            text: "Local LLM"
            font.bold: true
            font.pixelSize: Math.round(Theme.em * 1.15)
        }
        Ink {
            text: Llm.state === "ready" ? "Serving " + Llm.served : Llm.state === "starting" ? "Starting " + (Llm.starting || "a model") + "…" : Llm.state === "stopping" ? (Llm.next ? "Switching to " + Llm.next + "…" : "Stopping…") : "Off"
            color: Llm.state === "ready" ? Theme.good : Theme.inkDim
        }
    }

    Column {
        width: root.contentWidth
        spacing: Theme.gap

        SectionTitle {
            text: "GPU memory"
        }
        Item {
            width: parent.width
            height: Math.round(Theme.em * 1.2)

            Ink {
                id: mem
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: isNaN(root.usedGiB) ? "?" : root.usedGiB.toFixed(1) + " / " + Math.round(root.totalGiB) + " GiB"
                font.pixelSize: Theme.small
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: mem.left
                anchors.rightMargin: Theme.gap
                anchors.verticalCenter: parent.verticalCenter
                height: Math.max(4, Math.round(Theme.em * 0.3))
                radius: height / 2
                color: Theme.rule
                opacity: 0.5
            }
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: (mem.x - Theme.gap) * (isNaN(root.usedGiB) ? 0 : Math.min(1, root.usedGiB / root.totalGiB))
                height: Math.max(4, Math.round(Theme.em * 0.3))
                radius: height / 2
                color: Theme.accent
            }
        }
    }

    Column {
        visible: Llm.state === "ready"
        width: root.contentWidth
        spacing: Theme.gap

        SectionTitle {
            text: "Activity"
        }
        Ink {
            text: Llm.requests + (Llm.requests === 1 ? " request" : " requests") + (Llm.waiting > 0 ? ", " + Llm.waiting + " waiting" : "") + (Llm.tokensPerSecond >= 1 ? "  ·  " + Math.round(Llm.tokensPerSecond) + " tok/s" : "")
        }
        Ink {
            text: "KV cache " + (isNaN(Llm.kvUsage) ? "?" : Math.round(Llm.kvUsage * 100) + "%")
            color: Theme.inkDim
            font.pixelSize: Theme.small
        }
    }

    Rule {}

    Column {
        width: root.contentWidth
        spacing: 2

        Item {
            width: parent.width
            height: logButton.implicitHeight

            SectionTitle {
                anchors.verticalCenter: parent.verticalCenter
                text: "Models"
            }
            TextButton {
                id: logButton
                anchors.right: parent.right
                visible: Llm.container !== "" || Llm.starting !== ""
                text: "Log"
                onClicked: {
                    Llm.showLog();
                    Panels.close();
                }
            }
        }

        Repeater {
            model: Llm.models

            Rectangle {
                id: row

                required property string modelData
                readonly property bool current: modelData === Llm.served || modelData === Llm.starting
                readonly property bool busy: Llm.state !== "off"

                width: root.contentWidth
                height: Math.round(Theme.em * 1.9)
                radius: Math.round(Theme.radius * 0.6)
                color: row.current ? Theme.highlight : "transparent"

                Glyph {
                    id: mark
                    x: Math.round(Theme.gap * 0.6)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.icons.brain
                    color: row.current && Llm.state === "ready" ? Theme.ink : Theme.inkDim
                }
                Ink {
                    anchors.left: mark.right
                    anchors.leftMargin: Theme.gap
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData
                    font.bold: row.current
                }
                TextButton {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(Theme.gap * 0.4)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Llm.state !== "stopping"
                    text: row.current ? "Stop" : row.busy ? "Switch" : "Start"
                    strong: !row.current
                    onClicked: {
                        if (row.current)
                            Llm.stop();
                        else
                            Llm.start(row.modelData);
                    }
                }
            }
        }
    }
}
