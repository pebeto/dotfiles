import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// The thumbnail in the corner after a screenshot, as on macOS. Print runs
// sway/screenshot.sh, which copies the shot to the clipboard and calls
// `qs ipc call screenshot preview <file>`. Dragging it drops the file into
// another window (foot pastes its path, a browser uploads it), a click opens
// it in swappy to annotate, a right click saves it next to swappy's own
// saves, and a middle click dismisses it. It goes away after a few seconds,
// but not while the pointer is on it or it's being dragged.
Scope {
    id: root

    // The shot, a file in $XDG_RUNTIME_DIR; screenshot.sh keeps the last few.
    property string file: ""
    property string screenName: ""
    property bool saved: false
    property bool dragging: false
    property bool shown: false
    property bool up: false
    readonly property string saveDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property int pad: 32
    readonly property int maxWidth: Math.round(Theme.em * 14)
    readonly property int maxHeight: Math.round(Theme.em * 9)

    function show(path) {
        file = path;
        saved = false;
        screenName = Sway.focusedOutput;
        shown = true;
        up = true;
        timer.interval = 6000;
        timer.restart();
    }

    function dismiss() {
        timer.stop();
        up = false;
    }

    // The whole bubble, shadow included, as the drag's image, so the drag
    // looks like the bubble itself moving.
    function snapshot() {
        bubble.grabToImage(r => dragged.Drag.imageSource = r.url);
    }

    function save() {
        saver.command = ["sh", "-c", "mkdir -p \"$2\" && cp \"$1\" \"$2/\"", "sh", file, saveDir];
        saver.running = true;
    }

    IpcHandler {
        target: "screenshot"

        // Not "show", which `qs ipc` takes for its own subcommand.
        function preview(path: string): void {
            root.show(path);
        }
        // Before the next shot, so the thumbnail isn't in it.
        function hide(): void {
            timer.stop();
            root.up = false;
            root.shown = false;
        }
    }

    Timer {
        id: timer
        interval: 6000
        onTriggered: root.dismiss()
    }

    Process {
        id: saver
        onExited: code => {
            if (code !== 0)
                return;
            root.saved = true;
            timer.interval = 1500;
            timer.restart();
        }
    }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0]
        visible: root.shown
        anchors.bottom: true
        anchors.right: true
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-screenshot"
        color: "transparent"
        implicitWidth: card.width + root.pad * 2
        implicitHeight: card.height + root.pad * 2
        mask: Region {
            item: card
        }

        Item {
            id: bubble
            anchors.fill: parent

            Item {
                id: body

                x: root.pad
                y: root.pad
                width: card.width
                height: card.height
                transformOrigin: Item.BottomRight
                // Gone from the corner while a drag carries its image.
                opacity: root.up && !root.dragging ? 1 : 0
                scale: root.up ? 1 : 0.9

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.dragging ? 0 : root.up ? 160 : 120
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
                    blur: 20
                    color: "#66000000"
                }

                Rectangle {
                    id: card

                    width: Math.max(shot.width, Math.round(Theme.em * 10)) + Theme.gap * 2
                    height: shot.height + caption.implicitHeight + Theme.gap * 3
                    radius: Theme.radius
                    color: Theme.paper
                    border.width: 1
                    border.color: Theme.rule

                    ClippingRectangle {
                        id: shot

                        readonly property real aspect: image.implicitHeight > 0 ? image.implicitWidth / image.implicitHeight : 16 / 9

                        x: Math.round((card.width - width) / 2)
                        y: Theme.gap
                        width: Math.round(Math.min(root.maxWidth, root.maxHeight * aspect))
                        height: Math.round(width / aspect)
                        radius: Math.round(Theme.radius * 0.6)
                        color: Theme.paperHover

                        Image {
                            id: image
                            anchors.fill: parent
                            source: root.file ? "file://" + root.file : ""
                            sourceSize.width: root.maxWidth * 2
                            sourceSize.height: root.maxHeight * 2
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            smooth: true
                        }
                    }

                    Ink {
                        id: caption
                        x: Theme.gap
                        y: shot.y + shot.height + Theme.gap
                        width: card.width - Theme.gap * 2
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: root.saved ? "Saved to Pictures/Screenshots" : "Copied · drag it, click to edit, right-click to save"
                        color: root.saved ? Theme.good : Theme.inkDim
                        font.pixelSize: Theme.small
                    }

                    // What a drag carries: the file, with the bubble's image held
                    // where it was pressed. The compositor runs the drag, so this
                    // item only moves until it starts.
                    Item {
                        id: dragged

                        Drag.active: mouse.drag.active
                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction
                        Drag.mimeData: ({ "text/uri-list": "file://" + root.file + "\r\n" })
                        Drag.onDragStarted: {
                            root.dragging = true;
                            timer.stop();
                        }
                        Drag.onDragFinished: action => {
                            root.dragging = false;
                            dragged.x = 0;
                            dragged.y = 0;
                            if (action === Qt.IgnoreAction) {
                                timer.restart();
                            } else {
                                // Already invisible, so no fade to wait for.
                                timer.stop();
                                root.up = false;
                                root.shown = false;
                            }
                        }
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        drag.target: dragged
                        onContainsMouseChanged: {
                            if (containsMouse) {
                                timer.stop();
                                root.snapshot();
                            } else if (root.up && !root.dragging) {
                                timer.restart();
                            }
                        }
                        onPressed: e => {
                            const p = mapToItem(bubble, e.x, e.y);
                            dragged.Drag.hotSpot = Qt.point(p.x, p.y);
                            root.snapshot();
                        }
                        onClicked: e => {
                            if (e.button === Qt.LeftButton) {
                                Quickshell.execDetached(["swappy", "-f", root.file]);
                                root.dismiss();
                            } else if (e.button === Qt.RightButton) {
                                root.save();
                            } else {
                                root.dismiss();
                            }
                        }
                    }
                }
            }
        }
    }
}
