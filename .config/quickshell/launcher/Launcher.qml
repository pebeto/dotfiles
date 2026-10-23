import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// The app launcher and the clipboard-history picker, after Spotlight in
// macOS Tahoe: a search capsule that fades and springs in on the focused
// screen, and grows into a list of results as you type. For apps, Down on an
// empty search lists the most used ones; the clipboard opens on its newest
// entries. Both are Panels ("launcher" and "clipboard"), so opening one
// closes the bar's panels, and `qs ipc call panel toggle launcher` or
// `... clipboard` opens it (Super+space, XF86Favorites). Arrows, Tab or
// Ctrl+N/P move the selection, Enter picks, Escape or a click outside
// closes.
//
// Its shadow is drawn here rather than by swayfx, whose effects belong to
// the whole window and couldn't fade and scale with the card.
Scope {
    id: root

    readonly property string request: Panels.open === "launcher" ? "apps" : Panels.open === "clipboard" ? "clipboard" : ""
    // What's showing, "apps" or "clipboard". It outlives the request
    // through the closing fade, so the card doesn't change under it.
    property string mode: "apps"
    readonly property var screen: Quickshell.screens.find(s => s.name === Panels.screen) ?? Quickshell.screens[0]
    property string query: ""
    readonly property var results: mode === "apps" ? Apps.search(query).slice(0, 50) : Clipboard.search(query).slice(0, 200)
    property int current: 0
    property bool browsing: false
    readonly property bool expanded: query !== "" || browsing || mode === "clipboard"

    readonly property int rows: 8
    readonly property int rowHeight: Math.round(Theme.em * 1.9)
    readonly property int cardWidth: Theme.panelWidth + Theme.gap * 4
    readonly property int barHeight: Math.round(Theme.em * 2.8)
    readonly property int fullHeight: barHeight + 1 + rows * rowHeight + Theme.gap * 2
    // Room around the card for its shadow, inside the window.
    readonly property int pad: Math.round(Theme.em * 2.5)
    // Where the capsule sits: about a fifth of the way down.
    readonly property int restTop: Math.round((screen?.height ?? 1080) * 0.2)

    // `shown` maps the window; `up` is the card fading and springing in.
    property bool shown: false
    property bool up: false

    function move(steps) {
        if (results.length === 0)
            return;
        current = Math.max(0, Math.min(results.length - 1, current + steps));
        list.positionViewAtIndex(current, ListView.Contain);
    }

    function launch(index) {
        const r = results[index];
        if (!r || !expanded)
            return;
        Panels.close();
        if (mode === "apps")
            Apps.launch(r.entry);
        else
            Clipboard.restore(r.entry);
    }

    // The app's name (or the clipboard preview) with the matched letters in
    // the link color, plus the generic name in gray. StyledText, so the text
    // itself is escaped first.
    function label(r) {
        const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const text = mode === "apps" ? r.entry.name : r.entry.text;
        let out = "";
        for (let i = 0; i < text.length; i++)
            out += r.hits.includes(i) ? `<font color="${Theme.link}">${esc(text[i])}</font>` : esc(text[i]);
        const generic = mode === "apps" ? r.entry.genericName : "";
        if (generic && generic !== text)
            out += `&nbsp;&nbsp;<font color="${Theme.inkDim}">${esc(generic)}</font>`;
        return out;
    }

    // Also runs when one mode is asked for while the other is open.
    onRequestChanged: {
        if (request === "") {
            // Closed again before the card left 0: nothing will fade out,
            // and the window mustn't keep the keyboard.
            if (body.opacity === 0)
                shown = false;
            up = false;
            return;
        }
        mode = request;
        if (mode === "clipboard")
            Clipboard.refresh();
        input.text = "";
        browsing = false;
        current = 0;
        list.positionViewAtBeginning();
        shown = true;
        up = true;
        input.forceActiveFocus();
    }

    // A transparent layer over the screen catches the click outside.
    PanelWindow {
        screen: root.screen
        visible: root.request !== ""
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-launcher-shade"
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: Panels.close()
        }
    }

    PanelWindow {
        id: window

        screen: root.screen
        visible: root.shown
        anchors.top: true
        margins.top: root.restTop - root.pad
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"
        implicitWidth: root.cardWidth + root.pad * 2
        implicitHeight: root.fullHeight + root.pad * 2
        // Only the card takes clicks; around it they reach the shade.
        mask: Region {
            item: card
        }

        Item {
            id: body

            x: root.pad
            y: root.pad
            width: root.cardWidth
            height: card.height
            // Springs in from a little smaller, growing from the capsule's top.
            transformOrigin: Item.Top
            opacity: root.up ? 1 : 0
            scale: root.up ? 1 : 0.9

            Behavior on opacity {
                NumberAnimation {
                    duration: root.up ? 160 : 120
                    easing.type: root.up ? Easing.OutCubic : Easing.InCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.up ? 320 : 120
                    easing.type: root.up ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: 1.6
                }
            }
            onOpacityChanged: {
                if (opacity === 0 && !root.up)
                    root.shown = false;
            }

            RectangularShadow {
                anchors.fill: card
                radius: card.radius
                blur: Math.round(Theme.em * 1.6)
                offset.y: Math.round(Theme.em * 0.4)
                color: "#4d000000"
            }

            ClippingRectangle {
                id: card

                width: root.cardWidth
                height: root.expanded ? root.fullHeight : root.barHeight
                radius: root.expanded ? Theme.radius * 2 : root.barHeight / 2
                color: Theme.paper

                Behavior on height {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on radius {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    id: bar

                    x: Theme.gap * 2
                    width: parent.width - Theme.gap * 4
                    height: root.barHeight

                    Glyph {
                        id: searchGlyph
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.mode === "apps" ? Theme.icons.search : Theme.icons.clipboard
                        color: Theme.inkDim
                        font.pixelSize: Math.round(Theme.em * 1.3)
                    }
                    Ink {
                        anchors.left: searchGlyph.right
                        anchors.leftMargin: Theme.gap
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: root.mode === "apps" ? "Search applications" : "Search clipboard history"
                        color: Theme.inkDim
                        font.pixelSize: Math.round(Theme.em * 1.15)
                    }
                    TextInput {
                        id: input

                        anchors.left: searchGlyph.right
                        anchors.leftMargin: Theme.gap
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Theme.font
                        font.pixelSize: Math.round(Theme.em * 1.15)
                        color: Theme.ink
                        selectionColor: Theme.highlight
                        selectedTextColor: Theme.ink
                        clip: true
                        focus: true
                        onTextChanged: {
                            root.query = text;
                            root.current = 0;
                            list.positionViewAtBeginning();
                        }
                        Keys.onPressed: e => {
                            const ctrl = e.modifiers & Qt.ControlModifier;
                            const down = e.key === Qt.Key_Down || e.key === Qt.Key_Tab || (ctrl && e.key === Qt.Key_N);
                            if (e.key === Qt.Key_Escape)
                                Panels.close();
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                                root.launch(root.current);
                            else if (down && !root.expanded)
                                root.browsing = true;
                            else if (down)
                                root.move(1);
                            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (ctrl && e.key === Qt.Key_P))
                                root.move(-1);
                            else if (e.key === Qt.Key_PageDown)
                                root.move(root.rows);
                            else if (e.key === Qt.Key_PageUp)
                                root.move(-root.rows);
                            else
                                return;
                            e.accepted = true;
                        }
                    }
                }

                // The results, faded in as the capsule grows.
                Column {
                    x: Theme.gap
                    y: root.barHeight
                    width: parent.width - Theme.gap * 2
                    opacity: root.expanded ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rule {}

                    ListView {
                        id: list

                        width: parent.width
                        height: root.rows * root.rowHeight
                        topMargin: Theme.gap
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.results

                        delegate: Rectangle {
                            id: row

                            required property var modelData
                            required property int index

                            width: list.width
                            height: root.rowHeight
                            radius: Theme.radius
                            color: index === root.current ? Theme.highlight : "transparent"
                            clip: true

                            IconImage {
                                id: appIcon
                                x: Theme.gap
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: Math.round(Theme.em * 1.3)
                                visible: root.mode === "apps"
                                source: root.mode === "apps" ? Quickshell.iconPath(row.modelData.entry.icon, "application-x-executable") : ""
                            }
                            Glyph {
                                x: Theme.gap
                                width: appIcon.width
                                horizontalAlignment: Text.AlignHCenter
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.mode === "clipboard"
                                text: row.modelData.entry.image ? Theme.icons.image : Theme.icons.text
                                color: Theme.inkDim
                            }
                            Ink {
                                anchors.left: appIcon.right
                                anchors.leftMargin: Theme.gap
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.gap
                                anchors.verticalCenter: parent.verticalCenter
                                textFormat: Text.StyledText
                                text: root.label(row.modelData)
                            }

                            // Moving the pointer selects; position rather
                            // than enter, so a list the keys scrolled under
                            // a still pointer keeps the keyboard's choice.
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: root.current = row.index
                                onClicked: root.launch(row.index)
                            }
                        }

                        Ink {
                            anchors.centerIn: parent
                            visible: root.results.length === 0
                            text: root.mode === "apps" ? "No matching applications" : root.query === "" ? "The clipboard history is empty" : "No matching entries"
                            color: Theme.inkDim
                        }
                    }
                }
            }

            // The same hairline as the other cards, drawn over the clipped
            // content.
            Rectangle {
                anchors.fill: card
                radius: card.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.rule
            }
        }
    }
}
