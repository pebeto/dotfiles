import QtQuick
import qs
import qs.components
import qs.services

// A day's agenda, today's unless told otherwise, grouped under one heading
// per org category, with times in their own column and the TODO keywords
// colored as in the old popup.
Column {
    id: root

    property var groups: Agenda.groups
    property string note: Agenda.note
    readonly property int timeWidth: Math.round(Theme.em * 3.6)

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function colorize(s) {
        const marks = [
            [/\bTODO\b/g, Theme.critical],
            [/\bDONE\b/g, Theme.good],
            [/\bNEXT\b/g, Theme.olive],
            [/\bWAITING\b/g, Theme.rule],
            [/\bDeadline:/g, Theme.critical],
            [/\bScheduled:/g, Theme.link]
        ];
        let out = escapeHtml(s);
        for (const [re, color] of marks)
            out = out.replace(re, m => `<font color="${color}">${m}</font>`);
        return out;
    }

    spacing: Math.round(Theme.gap * 0.8)

    Repeater {
        model: root.groups

        Column {
            required property var modelData

            width: root.width
            spacing: Math.round(Theme.gap * 0.3)

            Ink {
                text: modelData.category
                color: Theme.olive
                font.pixelSize: Theme.small
                font.bold: true
            }

            Repeater {
                model: modelData.items

                Item {
                    required property var modelData

                    width: root.width
                    height: Math.max(timeLabel.implicitHeight, entryLabel.implicitHeight)

                    Ink {
                        id: timeLabel
                        width: root.timeWidth
                        text: modelData.time || "•"
                        color: modelData.time ? Theme.link : Theme.inkDim
                        horizontalAlignment: modelData.time ? Text.AlignLeft : Text.AlignHCenter
                        font.pixelSize: Theme.small
                        verticalAlignment: Text.AlignTop
                        topPadding: Math.round((Theme.em - Theme.small) / 2)
                    }

                    Ink {
                        id: entryLabel
                        x: root.timeWidth
                        width: root.width - root.timeWidth
                        text: root.colorize(modelData.text)
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        verticalAlignment: Text.AlignTop
                    }
                }
            }
        }
    }

    Ink {
        visible: root.groups.length === 0
        width: root.width
        wrapMode: Text.Wrap
        text: root.note || "Nothing scheduled"
        color: Theme.inkDim
    }
}
