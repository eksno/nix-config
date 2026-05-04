#!/usr/bin/env bash
# Reap breezy-sideview when the Rayneo glasses disconnect.
#
# Listens on Hyprland's socket2 event stream for monitor-removed events.
# The glasses identify as "Technical Concepts Ltd SmartGlasses" in EDID;
# Hyprland surfaces the description in the `monitorremovedv2` event payload.
# When matched, send SIGTERM to the live breezy-sideview wrapper so its
# trap reaps the nested gnome-shell child cleanly.

set -euo pipefail

: "${HYPRLAND_INSTANCE_SIGNATURE:?must be set in a Hyprland session}"
: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR must be set}"

socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
pid_file="$XDG_RUNTIME_DIR/breezy-sideview/instance.pid"

# Glasses EDID match — same string the monitor.conf line uses for `desc:`.
# `monitorremovedv2` payload format: ID,NAME,DESCRIPTION
glasses_re='SmartGlasses'

reap_sideview() {
    [[ -f "$pid_file" ]] || return 0
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    [[ -n "$pid" ]] || return 0
    kill -0 "$pid" 2>/dev/null || { rm -f "$pid_file"; return 0; }
    kill -TERM "$pid"
}

socat -U - "UNIX-CONNECT:$socket" | while IFS= read -r line; do
    case "$line" in
        monitorremoved*|monitorremovedv2*)
            if [[ "$line" == *"$glasses_re"* ]]; then
                reap_sideview
            fi
            ;;
    esac
done
