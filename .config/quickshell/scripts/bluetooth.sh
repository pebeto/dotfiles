#!/bin/bash
# Bluetooth actions for the Quickshell panel. Every bluetoothctl call has a
# timeout: with bluetoothd stopped, bluetoothctl blocks rather than failing.
#
#   on               start bluetoothd if needed, unblock the radio and
#                    power the controller on
#   off              power the controller off
#   connect MAC      pair and trust it if it's new, then connect; prints
#                    ok or fail
#   disconnect MAC   prints ok or fail

set -u

bt() { timeout "${BT_TIMEOUT:-6}" bluetoothctl "$@"; }

case "${1:-}" in
on)
    # Starting the service needs a polkit agent and fails fast without one.
    systemctl is-active --quiet bluetooth || timeout 10 systemctl start bluetooth >/dev/null 2>&1
    # The T470's adapter de-registers while rfkill blocks it, so wait for
    # bluez to see the controller again before powering it.
    rfkill unblock bluetooth 2>/dev/null
    for _ in $(seq 1 12); do
        [ -n "$(bt list 2>/dev/null)" ] && break
        sleep 0.5
    done
    bt power on >/dev/null 2>&1
    ;;
off)
    bt power off >/dev/null 2>&1
    ;;
connect)
    # pair and trust are harmless no-ops for a device bluez already knows.
    bt pair "$2" >/dev/null 2>&1
    bt trust "$2" >/dev/null 2>&1
    if BT_TIMEOUT=15 bt connect "$2" >/dev/null 2>&1; then echo ok; else echo fail; fi
    ;;
disconnect)
    if bt disconnect "$2" >/dev/null 2>&1; then echo ok; else echo fail; fi
    ;;
*)
    echo "usage: $0 {on|off|connect MAC|disconnect MAC}" >&2
    exit 2
    ;;
esac
