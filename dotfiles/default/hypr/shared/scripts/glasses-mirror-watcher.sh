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
#   VG258 + glasses present    -> VG258 source @60; eDP-1 + glasses mirror it.
#   VG258 present (no glasses)  -> VG258 source @119.98; eDP-1 mirrors it.
#   glasses present (no VG258)  -> glasses are source; eDP-1 mirrors glasses.
#   neither                     -> eDP-1 native.
#
# Refresh split: 120 Hz across eDP-1 + HDMI + glasses (the 3-way chain) exceeds
# the Intel CDCLK budget and trips Hyprland's page-flip watchdog, so the VG258 is
# capped to 60 Hz ONLY when the glasses are also in the chain. Two-way eDP-1 +
# HDMI @120 is within budget (verified working, FIXES.md 2026-05-05), so the
# VG258 runs at its native 119.98 Hz whenever the glasses are absent.

set -uo pipefail

: "${HYPRLAND_INSTANCE_SIGNATURE:?must be set in a Hyprland session}"
: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR must be set}"

socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Match the glasses by EDID description, not connector name: the Rayneo comes
# up as DP-1 or DP-2 unpredictably across replugs.
glasses_desc="desc:Technical Concepts Ltd SmartGlasses"
glasses_re="SmartGlasses"

# Bind the external profile to THIS exact monitor by EDID make+model+serial,
# not the bare HDMI-A-1 connector — so the topology can't misfire on some other
# HDMI display and stays correct if the connector name ever shifts.
vg258_desc="desc:ASUSTek COMPUTER INC VG258 JCLMQS018649"
vg258_re="VG258 JCLMQS018649"

# Under the Lua config manager `hyprctl keyword` is rejected ("keyword can't work
# with non-legacy parsers. Use eval."), so monitor rules go through `hyprctl eval`
# with hl.monitor(). The descriptions contain no quotes, so plain double-quoted
# Lua literals are safe.
mon() {
    # mon OUTPUT MODE POSITION SCALE [MIRROR]
    local lua="output = \"$1\", mode = \"$2\", position = \"$3\", scale = $4"
    [[ -n "${5:-}" ]] && lua+=", mirror = \"$5\""
    printf 'hl.monitor({ %s }); ' "$lua"
}

apply_topology() {
    local mons vg258 glasses lua
    mons="$(hyprctl monitors all -j 2>/dev/null)" || return 0
    [[ -n "$mons" ]] || return 0

    vg258="$(jq -r --arg re "$vg258_re" 'any(.[]; .description | test($re))' <<<"$mons" 2>/dev/null)"
    glasses="$(jq -r --arg re "$glasses_re" 'any(.[]; .description | test($re))' <<<"$mons" 2>/dev/null)"

    if [[ "$vg258" == "true" ]]; then
        if [[ "$glasses" == "true" ]]; then
            # Three-way chain: VG258 is the canonical 1920x1080 source; eDP-1 and
            # the glasses both mirror it. 60 Hz cap is mandatory — 120 Hz across
            # all three exceeds the Intel CDCLK budget and trips Hyprland's
            # page-flip watchdog (see header + FIXES.md 2026-05-24).
            lua="$(mon "$vg258_desc" 1920x1080@60 0x0 1)"
            lua+="$(mon eDP-1 2880x1800@120 0x0 1.25 "$vg258_desc")"
            lua+="$(mon "$glasses_desc" 1920x1080@120 auto 1 "$vg258_desc")"
        else
            # VG258 standalone (no glasses): run it at its native 119.98 Hz.
            # Two-way eDP-1 + HDMI @120 stays within the CDCLK budget; only the
            # three-way case above needs the 60 Hz cap.
            lua="$(mon "$vg258_desc" 1920x1080@119.98 0x0 1)"
            lua+="$(mon eDP-1 2880x1800@120 0x0 1.25 "$vg258_desc")"
        fi
    elif [[ "$glasses" == "true" ]]; then
        # Glasses are the canonical source; laptop mirrors them. Clean, no bars
        # on the glasses.
        lua="$(mon "$glasses_desc" 1920x1080@120 0x0 1)"
        lua+="$(mon eDP-1 2880x1800@120 0x0 1.25 "$glasses_desc")"
    else
        # Bare laptop.
        lua="$(mon eDP-1 2880x1800@120 0x0 1.25)"
    fi
    hyprctl eval "$lua" >/dev/null 2>&1
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
