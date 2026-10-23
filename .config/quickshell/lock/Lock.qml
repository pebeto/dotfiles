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
// go through login's PAM stack, so faillock's limits stay the same.
//
// On hosts with a fingerprint reader (Theme's fingerprint flag) a second PAM
// context, pam/fingerprint, waits for a finger alongside the password, and
// whichever succeeds first unlocks. Keeping them apart means a typed password
// never waits on the reader. When pam_fprintd gives up after its tries,
// Enter on an empty field starts another scan.
//
// The reader doesn't survive a suspend: python-validity loses the USB device
// and restarts after resume, which can take several seconds. So swayidle
// calls `sleep` before suspending, which stops the scan, and `resume`
// afterwards. Until the reader answers, three dots stand in for the field.
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
    // The password or finger was accepted and the screen is fading out.
    property bool unlocking: false
    // The fingerprint context is waiting for a finger.
    property bool scanning: false
    property double scanStart: 0
    // The last error the reader showed.
    property string scanError: ""
    // The machine is suspending or suspended; don't touch the reader.
    property bool asleep: false
    // Waiting for the reader to answer, retrying until wakeUntil.
    property bool waking: false
    property double wakeUntil: 0
    // Loading dots for "Checking" and the reader coming back.
    property int dots: 0
    readonly property int fadeMs: 250

    function lock() {
        if (sessionLock.locked)
            return;
        password = "";
        error = "";
        unlocking = false;
        sessionLock.locked = true;
        if (!asleep)
            wake();
    }

    function wake() {
        if (!Theme.profile.fingerprint || unlocking || !sessionLock.locked)
            return;
        asleep = false;
        waking = true;
        wakeUntil = Date.now() + 20000;
        scan();
    }

    function sleep() {
        if (!sessionLock.locked) {
            asleep = true;
            lock();
        }
        rescan.stop();
        if (scanning)
            fingerprint.abort();
        scanning = false;
        asleep = true;
        error = "";
        waking = Theme.profile.fingerprint;
    }

    function scan() {
        if (!Theme.profile.fingerprint || asleep || scanning || unlocking || !sessionLock.locked)
            return;
        scanStart = Date.now();
        scanning = fingerprint.start();
    }

    function unlock() {
        if (checking)
            pam.abort();
        if (scanning)
            fingerprint.abort();
        rescan.stop();
        checking = false;
        scanning = false;
        waking = false;
        asleep = false;
        error = "";
        unlocking = true;
        release.start();
    }

    function tryUnlock() {
        if (password === "") {
            error = "";
            if (!scanning)
                wake();
            return;
        }
        if (checking || unlocking)
            return;
        checking = true;
        error = "";
        if (!pam.start()) {
            checking = false;
            error = "Couldn't check the password";
        }
    }

    Timer {
        interval: 400
        repeat: true
        running: root.checking || root.waking
        onRunningChanged: root.dots = 0
        onTriggered: root.dots = (root.dots + 1) % 4
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
                    // While the reader comes back the field gives way to three
                    // pulsing dots; typing brings it back.
                    Item {
                        id: field

                        readonly property bool hidden: root.waking && root.password === ""

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(Theme.em * 16)
                        height: Math.round(Theme.em * 2.2)

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.35)
                            opacity: field.hidden ? 0 : 1

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                }
                            }

                            Txt {
                                anchors.centerIn: parent
                                width: parent.width - Theme.gap * 2
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideLeft
                                text: root.password !== "" ? "•".repeat(root.password.length) : root.scanning || rescan.running ? "Password or finger" : "Password"
                                opacity: root.password !== "" && !root.checking ? 1 : 0.6
                            }
                        }
                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.gap
                            opacity: field.hidden ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                }
                            }

                            Repeater {
                                model: 3

                                Rectangle {
                                    required property int index

                                    width: Math.round(Theme.em * 0.5)
                                    height: width
                                    radius: width / 2
                                    color: Theme.fg
                                    opacity: root.dots === index + 1 ? 1 : 0.3

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        // The dots not shown yet are drawn transparent, so the
                        // centered text holds still while they fill in.
                        text: root.checking ? "Checking" + ".".repeat(root.dots) + "<font color=\"transparent\">" + ".".repeat(3 - root.dots) + "</font>" : root.error
                        textFormat: root.checking ? Text.StyledText : Text.PlainText
                        color: root.checking ? Theme.fg : "#ff8a80"
                        opacity: text !== "" ? 1 : 0
                    }
                }
            }
        }
    }

    PamContext {
        id: pam

        config: "login"
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
                root.unlock();
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

    PamContext {
        id: fingerprint

        configDirectory: Quickshell.shellPath("pam")
        config: "fingerprint"
        // "Failed to match fingerprint" and the like; the "place your
        // finger" prompts are left to the field's placeholder.
        onPamMessage: {
            // Any prompt means the reader is up.
            if (!messageIsError)
                root.waking = false;
            else if (!root.checking) {
                root.error = message;
                root.scanError = message;
            }
        }
        onCompleted: result => {
            root.scanning = false;
            if (root.unlocking || root.asleep || !sessionLock.locked)
                return;
            if (result === PamResult.Success)
                root.unlock();
            else if (result === PamResult.MaxTries) {
                root.waking = false;
                root.error = "Too many tries, press Enter to scan again";
            } else {
                // A timeout (pam_fprintd's 30 s) or a reader that isn't
                // there. The error is stale either way. After a timeout scan
                // again; a quick failure means the driver is down, so keep
                // retrying with the dots up until wakeUntil, then leave it
                // to the password.
                if (root.error === root.scanError)
                    root.error = "";
                if (Date.now() - root.scanStart < 5000) {
                    if (!root.waking) {
                        root.waking = true;
                        root.wakeUntil = Date.now() + 20000;
                    }
                    if (Date.now() > root.wakeUntil) {
                        root.waking = false;
                        return;
                    }
                }
                rescan.start();
            }
        }
        onError: () => {
            root.scanning = false;
            root.waking = false;
        }
    }

    Timer {
        id: rescan
        interval: 1000
        onTriggered: root.scan()
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
        function sleep(): void {
            root.sleep();
        }
        function resume(): void {
            root.wake();
        }
        function secure(): bool {
            return sessionLock.secure;
        }
    }
}
