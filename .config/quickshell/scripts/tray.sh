#!/bin/bash
# Exits 0 if the tray item with Id $1 can be activated, and 1 if it has no
# Activate method or isn't registered. libappindicator apps such as Steam
# have none, only a menu; services/Tray.qml asks on each left click.

set -u

id=${1:?id}
watcher=(org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher)
busctl --user --json=short get-property "${watcher[@]}" RegisteredStatusNotifierItems 2>/dev/null |
    jq -r '.data[]' | {
    while IFS= read -r item; do
        # Each entry is "service/object/path", or just the service when the
        # item sits at the default /StatusNotifierItem.
        service=${item%%/*}
        path=/StatusNotifierItem
        [[ $item == */* ]] && path=/${item#*/}
        [ "$(busctl --user --json=short get-property "$service" "$path" org.kde.StatusNotifierItem Id 2>/dev/null | jq -r '.data')" = "$id" ] || continue
        busctl --user introspect "$service" "$path" org.kde.StatusNotifierItem 2>/dev/null | grep -q '^\.Activate '
        exit
    done
    exit 1
}
