#!/usr/bin/env bash
# Recenter the XR pose by writing the IPC control flag the daemon polls.
# Path + key name match XRLinuxDriver src/state.c:
#   state_files_directory = "/dev/shm"
#   control_flags_filename = "xr_driver_control"
#   recognized: recenter_screen=true|false (single-shot, daemon clears it)

set -euo pipefail
ctl="/dev/shm/xr_driver_control"
printf 'recenter_screen=true\n' > "$ctl"
