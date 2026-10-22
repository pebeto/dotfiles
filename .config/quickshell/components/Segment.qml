import QtQuick
import qs

// An icon and a short label side by side, as one bar reading ("52°"). The
// icon stays dim unless the reading itself is tinted (a warning, say).
Row {
    id: root

    property string icon: ""
    property string label: ""
    property color tint: Theme.fg
    property color iconTint: Qt.colorEqual(tint, Theme.fg) ? Theme.dim : tint

    spacing: Math.round(Theme.em * 0.3)

    Glyph {
        height: Theme.barHeight
        text: root.icon
        color: root.iconTint
        visible: text !== ""
    }
    Txt {
        height: Theme.barHeight
        text: root.label
        color: root.tint
        visible: text !== ""
    }
}
