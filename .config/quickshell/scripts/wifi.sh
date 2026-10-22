#!/bin/bash
# WiFi helper for the Quickshell bar and its WiFi panel, on iwd. Prints
# tab-separated lines for the QML side to split, and never prompts.
#
#   status               off | on | connected<TAB>ssid<TAB>dBm
#   list                 scan, then one line per network:
#                        connected<TAB>known<TAB>security<TAB>bars 0-4<TAB>ssid
#   connect SSID [PASS]  join SSID; PASS is only used if iwd has no
#                        stored credential for it. Prints ok or fail.
#   disconnect
#   power on|off         unblock or block the radio (rfkill)

set -u

iface=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')

strip_ansi() { sed -E 's/\x1b\[[0-9;]*[mKHGJ]//g'; }

# Names of the networks iwd has credentials for, one per line. The name is
# everything before the security column, as in `list` below.
known_networks() {
    iwctl known-networks list 2>/dev/null | strip_ansi |
        awk 'match($0, /[[:space:]](psk|open|8021x|wep)([[:space:]]|$)/) {
                 name = substr($0, 1, RSTART - 1)
                 gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
                 if (name != "" && name != "Name") print name
             }'
}

case "${1:-}" in
status)
    if [ -z "$iface" ] || [ "$(rfkill list wifi -o SOFT -n 2>/dev/null | head -1)" = blocked ]; then
        echo off
        exit 0
    fi
    link=$(iw dev "$iface" link 2>/dev/null)
    ssid=$(printf '%s\n' "$link" | sed -n 's/^\tSSID: //p')
    dbm=$(printf '%s\n' "$link" | sed -n 's/^\tsignal: \(-\{0,1\}[0-9]*\).*/\1/p')
    if [ -n "$ssid" ]; then
        printf 'connected\t%s\t%s\n' "$ssid" "$dbm"
    else
        echo on
    fi
    ;;
list)
    [ -n "$iface" ] || exit 1
    iwctl station "$iface" scan >/dev/null 2>&1
    sleep 1.5
    # iwctl draws signal as four stars and grays out the missing ones, so
    # the bars are the stars before the first gray escape. The security
    # keyword splits each row: the SSID (spaces and all) is everything
    # before it, and a leading ">" marks the connected network.
    iwctl station "$iface" get-networks 2>/dev/null |
        awk -v known="$(known_networks)" '
            BEGIN { n = split(known, k, "\n"); for (i = 1; i <= n; i++) isknown[k[i]] = 1 }
            {
                raw = $0
                plain = raw; gsub(/\x1b\[[0-9;]*[mKHGJ]/, "", plain)
                if (!match(plain, /[[:space:]](psk|open|8021x|wep)([[:space:]]|$)/)) next
                ssid = substr(plain, 1, RSTART - 1)
                sec = substr(plain, RSTART + 1, RLENGTH - 1); gsub(/[[:space:]]/, "", sec)
                connected = (ssid ~ /^[[:space:]]*>/) ? 1 : 0
                sub(/^[[:space:]]*>?[[:space:]]*/, "", ssid); sub(/[[:space:]]+$/, "", ssid)
                if (ssid == "" || ssid == "Network name") next
                match(raw, /[[:space:]](psk|open|8021x|wep)([[:space:]]|$)/)
                sig = substr(raw, RSTART + RLENGTH)
                sub(/\x1b\[1;90m.*/, "", sig); gsub(/\x1b\[[0-9;]*[mKHGJ]/, "", sig)
                bars = gsub(/\*/, "", sig)
                if (!seen[ssid]++) printf "%d\t%d\t%s\t%d\t%s\n", connected, (ssid in isknown), sec, bars, ssid
            }'
    ;;
connect)
    ssid=${2:?ssid}
    pass=${3:-}
    # With stdin closed iwctl fails at once instead of prompting, so a
    # network that needs a passphrase falls through to the second try.
    if iwctl station "$iface" connect "$ssid" </dev/null >/dev/null 2>&1; then
        echo ok
    elif [ -n "$pass" ] && iwctl --passphrase "$pass" station "$iface" connect "$ssid" </dev/null >/dev/null 2>&1; then
        echo ok
    else
        echo fail
    fi
    ;;
disconnect)
    iwctl station "$iface" disconnect >/dev/null 2>&1
    ;;
power)
    case "${2:-}" in
    on) rfkill unblock wifi ;;
    off) rfkill block wifi ;;
    esac
    ;;
*)
    echo "usage: $0 {status|list|connect SSID [PASS]|disconnect|power on|off}" >&2
    exit 2
    ;;
esac
