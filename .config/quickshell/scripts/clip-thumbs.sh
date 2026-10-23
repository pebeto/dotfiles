#!/bin/bash
# Decodes clipboard-history images for the picker's thumbnails. $1 is the
# folder, and each further argument is "file=line", with line being
# cliphist's own "id<TAB>preview" line. Files already there are kept, since
# an id always holds the same image; files of images no longer in the
# history are deleted.

set -u

dir=${1:?dir}
shift
mkdir -p "$dir" && cd "$dir" || exit 1

declare -A keep=()
for e in "$@"; do
    f=${e%%=*}
    keep[$f]=1
    [ -s "$f" ] || printf '%s\n' "${e#*=}" | cliphist decode > "$f"
done
for f in *; do
    [ -e "$f" ] && [ -z "${keep[$f]:-}" ] && rm -f -- "$f"
done
exit 0
