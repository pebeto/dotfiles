#!/bin/bash
# Activates the tray item with Id $1, which normally brings its window up.
# Exits 1 when that fails: the item isn't registered, or it has no Activate
# method at all (libappindicator apps such as Steam offer only a menu), so
# services/Tray.qml can open the app another way. Trying is the only
# reliable test, since some apps (Electron ones) don't describe their
# methods over introspection.

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
        busctl --user --timeout=2 call "$service" "$path" org.kde.StatusNotifierItem Activate ii 0 0 >/dev/null 2>&1
        exit
    done
    exit 1
}
