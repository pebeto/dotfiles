#!/bin/bash
# Single barspec entry point. Sources the shared scaffolding (fifo +
# click handler + JSON header) and then the per-host script, which sets
# colors, defines metric functions, and runs the render loop.
#
# Per-host selection: ~/.config/sway-host.sh is a symlink each machine
# creates to one of hosts/<name>.sh.

# shellcheck source=barspec-lib.sh
source ~/.config/sway/barspec-lib.sh

# shellcheck source=/dev/null
source ~/.config/sway-host.sh
