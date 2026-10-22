import QtQuick
import qs

// Plain text in the shell's font. The defaults suit the bar; popups set
// their own color and size.
Text {
    font.family: Theme.font
    font.pixelSize: Theme.em
    color: Theme.fg
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
}
