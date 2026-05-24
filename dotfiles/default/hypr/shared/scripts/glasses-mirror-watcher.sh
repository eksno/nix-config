#!/usr/bin/env bash
# Keep the Rayneo glasses mirrored cleanly across hotplug/reboot.
#
# Static monitor= rules can't express "mirror VG258 if present, else mirror
# glasses": Hyprland is last-match-wins, and a mirror rule whose target is
# ABSENT clobbers the output to standalone rather than falling through to an
# earlier rule (verified 2026-05-24). So topology selection has to be
# imperative. This script listens on Hyprland's socket2 event stream and
# re-applies the correct mirror layout whenever a monitor is added/removed.
#
# Aspect handling: the glasses are 1920x1080 (16:9), the laptop eDP-1 is
# 2880x1800 (16:10). We make the SMALLER-aspect source canonical and have the
# laptop mirror it — so the glasses render their native framebuffer with zero
# scaling and zero bars. The 16:9 image on the 16:10 laptop panel looks off,
# but you're wearing the glasses, not staring at the laptop.
#
#   VG258 (HDMI-A-1) present  -> VG258 is source; eDP-1 + glasses mirror it.
#   glasses present (no VG258) -> glasses are source; eDP-1 mirrors glasses.
#   neither                    -> eDP-1 native.

set -uo pipefail

: "${HYPRLAND_INSTANCE_SIGNATURE:?must be set in a Hyprland session}"
: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR must be set}"

socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Match the glasses by EDID description, not connector name: the Rayneo comes
# up as DP-1 or DP-2 unpredictably across replugs.
glasses_desc="desc:Technical Concepts Ltd SmartGlasses"
glasses_re="SmartGlasses"

apply_topology() {
    local mons vg258 glasses
    mons="$(hyprctl monitors all -j 2>/dev/null)" || return 0
    [[ -n "$mons" ]] || return 0

    vg258="$(jq -r 'any(.[]; .name == "HDMI-A-1")' <<<"$mons" 2>/dev/null)"
    glasses="$(jq -r --arg re "$glasses_re" 'any(.[]; .description | test($re))' <<<"$mons" 2>/dev/null)"

    if [[ "$vg258" == "true" ]]; then
        # VG258 is the canonical 1920x1080 source. 60 Hz cap: 120 Hz across
        # eDP-1 + HDMI-A-1 + glasses exceeds the Intel CDCLK budget and trips
        # Hyprland's page-flip watchdog (see monitor.conf history).
        hyprctl --batch "\
keyword monitor HDMI-A-1,1920x1080@60,0x0,1 ; \
keyword monitor eDP-1,2880x1800@120,0x0,1.25,mirror,HDMI-A-1" >/dev/null 2>&1
        if [[ "$glasses" == "true" ]]; then
            hyprctl keyword monitor "$glasses_desc,1920x1080@120,auto,1,mirror,HDMI-A-1" >/dev/null 2>&1
        fi
    elif [[ "$glasses" == "true" ]]; then
        # Glasses are the canonical source; laptop mirrors them. Clean, no bars
        # on the glasses.
        hyprctl --batch "\
keyword monitor $glasses_desc,1920x1080@120,0x0,1 ; \
keyword monitor eDP-1,2880x1800@120,0x0,1.25,mirror,$glasses_desc" >/dev/null 2>&1
    else
        # Bare laptop.
        hyprctl keyword monitor "eDP-1,2880x1800@120,0x0,1.25" >/dev/null 2>&1
    fi
}

# Apply once at session start (covers glasses already plugged in at login).
apply_topology

# React to hotplug. monitoraddedv2 fires before the output is fully settled,
# so debounce briefly before re-applying.
socat -U - "UNIX-CONNECT:$socket" | while IFS= read -r line; do
    case "$line" in
        monitoradded*|monitorremoved*)
            sleep 1
            apply_topology
            ;;
    esac
done
