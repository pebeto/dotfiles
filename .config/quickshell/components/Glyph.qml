import QtQuick
import qs

// One icon from the Nerd Font symbols (see Theme.icons).
Text {
    font.family: Theme.iconFont
    font.pixelSize: Math.round(Theme.em * 1.1)
    color: Theme.fg
    verticalAlignment: Text.AlignVCenter
}
