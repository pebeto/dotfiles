import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs
import qs.components

// The lock screen. sway/lock.sh asks for it over IPC, falling back to
// swaylock when the shell isn't running, and waits until `secure` says every
// screen is covered, which is what swayidle's before-sleep needs. Passwords
// go through swaylock's PAM stack, so faillock's limits stay the same.
//
// It fades up from black, so nothing of the desktop shows even mid-animation,
// and on unlock it fades down to the plain wallpaper, the same one sway puts
// behind the windows, before letting go.
//
// If the shell dies while locked, sway keeps the screens blank and locked;
// lock again from a TTY to get a prompt back (see the README).
Scope {
    id: root

    property string password: ""
    property string error: ""
    property bool checking: false
    // The password was accepted and the screen is fading out.
    property bool unlocking: false
    readonly property int fadeMs: 250

    function lock() {
        if (sessionLock.locked)
            return;
        password = "";
        error = "";
        unlocking = false;
        sessionLock.locked = true;
    }

    function tryUnlock() {
        if (checking || unlocking || password === "")
            return;
        checking = true;
        error = "";
        if (!pam.start()) {
            checking = false;
            error = "Couldn't check the password";
        }
    }

    Timer {
        id: release
        interval: root.fadeMs
        onTriggered: {
            sessionLock.locked = false;
            root.password = "";
        }
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: surface

            color: "#000000"

            Image {
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/.config/wallpaper.jpeg"
                // The same crop as `bg ... fill` in sway/config, and the same
                // colors: the photo carries a Display P3 profile, which swaybg
                // applies and Qt ignores unless asked to convert.
                fillMode: Image.PreserveAspectCrop
                colorSpace.namedColorSpace: ColorSpace.SRgb
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: root.unlocking ? 0 : 0.45

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.fadeMs
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            // Every screen takes typing; it goes to whichever one has focus.
            Item {
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: e => {
                    e.accepted = true;
                    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                        root.tryUnlock();
                    else if (root.checking || root.unlocking)
                        return;
                    else if (e.key === Qt.Key_Backspace)
                        root.password = root.password.slice(0, -1);
                    else if (e.key === Qt.Key_Escape)
                        root.password = "";
                    else if (e.text !== "" && e.text.charCodeAt(0) >= 32)
                        root.password += e.text;
                }
            }

            // The outer item fades the content out on unlock; the column
            // inside rises and fades in when the screen locks.
            Item {
                anchors.fill: parent
                opacity: root.unlocking ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.fadeMs
                        easing.type: Easing.InOutQuad
                    }
                }

                Column {
                    id: content

                    anchors.centerIn: parent
                    spacing: Theme.gap
                    opacity: 0
                    transform: Translate {
                        id: rise
                        y: Theme.gap * 3
                    }

                    SequentialAnimation {
                        running: true

                        PauseAnimation {
                            duration: 80
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: content
                                property: "opacity"
                                to: 1
                                duration: 350
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: rise
                                property: "y"
                                to: 0
                                duration: 350
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        font.pixelSize: Theme.em * 5
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                        font.pixelSize: Math.round(Theme.em * 1.2)
                        opacity: 0.85
                    }
                    Item {
                        width: 1
                        height: Theme.gap * 3
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Quickshell.env("USER")
                        font.bold: true
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(Theme.em * 16)
                        height: Math.round(Theme.em * 2.2)
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.35)

                        Txt {
                            anchors.centerIn: parent
                            width: parent.width - Theme.gap * 2
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideLeft
                            text: root.password !== "" ? "•".repeat(root.password.length) : "Password"
                            opacity: root.password !== "" && !root.checking ? 1 : 0.6
                        }
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.checking ? "Checking" : root.error
                        color: root.checking ? Theme.fg : "#ff8a80"
                        opacity: text !== "" ? 1 : 0
                    }
                }
            }
        }
    }

    PamContext {
        id: pam

        config: "swaylock"
        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root.password);
        }
        // faillock explains itself ("the account is locked..."); keep that
        // over the generic message below.
        onPamMessage: {
            if (messageIsError)
                root.error = message;
        }
        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) {
                root.error = "";
                root.unlocking = true;
                release.start();
            } else {
                root.password = "";
                if (root.error === "")
                    root.error = result === PamResult.MaxTries ? "Too many attempts" : "Wrong password";
            }
        }
        onError: () => {
            root.checking = false;
            root.password = "";
            root.error = "Couldn't check the password";
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
        function secure(): bool {
            return sessionLock.secure;
        }
    }
}
