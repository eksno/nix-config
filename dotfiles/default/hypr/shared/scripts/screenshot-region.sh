#!/usr/bin/env bash
# Interactive region screenshot to clipboard.
#
# Pipeline: slurp (pick region) -> wayshot -o (capture real output) ->
# magick (crop to region) -> wl-copy (clipboard).
#
# grim/wayshot-g are broken under Hyprland's fractional-scale wp_viewport
# (see FIXES.md "hypr-screenshot-fractional-scaling"), so we capture the
# whole output and crop ourselves. wlr_screencopy can't read a mirrored
# output directly, so when slurp lands on a mirror we follow the chain to
# the source. The mirror may have a different *logical size* than the
# source (e.g. eDP-1 2304x1440 mirroring HDMI-A-1 1920x1080), in which
# case slurp's output-relative coords are in the mirror's logical space
# and must be remapped into the source's logical space before cropping.
# See FIXES.md "hypr-screenshot-mirrored-output" for the background.
#
# Steps are run against tempfiles rather than a single wayshot|magick|wl-copy
# pipeline: under `set -e` + `pipefail`, any noisy stderr from wayshot's
# MESA stack or a mid-pipeline EPIPE could silently abort the whole chain
# before wl-copy wrote, leaving the previous clipboard owner in place.
# See FIXES.md "hypr-screenshot-pipeline-swallowed-errors".

set -uo pipefail

die() {
    notify-send "Screenshot" "$1" -u critical
    exit 1
}

SLURP_OUT=$(slurp -f '%X %Y %w %h %o') || exit 0
[[ -z "$SLURP_OUT" ]] && exit 0
read -r X Y W H OUT <<< "$SLURP_OUT"

# Zero-size selection (click without drag) -> nothing to do.
[[ "$W" == "0" || "$H" == "0" ]] && exit 0

if [[ -z "${OUT:-}" || "$OUT" == "<unknown>" ]]; then
    die "Could not determine output for selection"
fi

MONITORS=$(hyprctl monitors all -j)

mon_field() {
    echo "$MONITORS" | jq -r --arg n "$1" --arg f "$2" '.[] | select(.name==$n) | .[$f]'
}
mon_name_by_id() {
    echo "$MONITORS" | jq -r --arg i "$1" '.[] | select((.id|tostring)==$i) | .name'
}

# Follow mirror chain to the real (capturable) output. Bounded to avoid
# pathological configs looping forever.
SRC="$OUT"
for _ in 1 2 3; do
    MIRROR_OF=$(mon_field "$SRC" mirrorOf)
    [[ "$MIRROR_OF" == "none" || -z "$MIRROR_OF" || "$MIRROR_OF" == "null" ]] && break
    NEXT=$(mon_name_by_id "$MIRROR_OF")
    [[ -z "$NEXT" || "$NEXT" == "null" ]] && break
    SRC="$NEXT"
done

# If the slurped output is a mirror of SRC with a different logical size,
# Hyprland stretches the source framebuffer to fill the mirror's logical
# space. Remap slurp coords (mirror-logical) to source-logical before we
# crop the source's framebuffer. When mirror == source, the ratios are
# 1.0 and this is a no-op.
mirror_w=$(awk -v w="$(mon_field "$OUT" width)" -v s="$(mon_field "$OUT" scale)" 'BEGIN { print w/s }')
mirror_h=$(awk -v h="$(mon_field "$OUT" height)" -v s="$(mon_field "$OUT" scale)" 'BEGIN { print h/s }')
src_w=$(awk -v w="$(mon_field "$SRC" width)" -v s="$(mon_field "$SRC" scale)" 'BEGIN { print w/s }')
src_h=$(awk -v h="$(mon_field "$SRC" height)" -v s="$(mon_field "$SRC" scale)" 'BEGIN { print h/s }')

X=$(awk -v v="$X" -v m="$mirror_w" -v s="$src_w" 'BEGIN { print v * s / m }')
Y=$(awk -v v="$Y" -v m="$mirror_h" -v s="$src_h" 'BEGIN { print v * s / m }')
W=$(awk -v v="$W" -v m="$mirror_w" -v s="$src_w" 'BEGIN { print v * s / m }')
H=$(awk -v v="$H" -v m="$mirror_h" -v s="$src_h" 'BEGIN { print v * s / m }')

# Source-logical -> source physical pixels for the crop.
SCALE=$(mon_field "$SRC" scale)
if [[ -z "$SCALE" || "$SCALE" == "null" ]]; then
    die "Could not read scale for $SRC"
fi

PX=$(awk -v v="$X" -v s="$SCALE" 'BEGIN { printf "%.0f", v * s }')
PY=$(awk -v v="$Y" -v s="$SCALE" 'BEGIN { printf "%.0f", v * s }')
PW=$(awk -v v="$W" -v s="$SCALE" 'BEGIN { printf "%.0f", v * s }')
PH=$(awk -v v="$H" -v s="$SCALE" 'BEGIN { printf "%.0f", v * s }')

TMP=$(mktemp --suffix=.png)
CROP="${TMP%.png}.crop.png"
trap 'rm -f "$TMP" "$CROP"' EXIT

if ! wayshot -o "$SRC" "$TMP" 2>/dev/null || [[ ! -s "$TMP" ]]; then
    die "wayshot failed on $SRC"
fi

if ! magick "$TMP" -crop "${PW}x${PH}+${PX}+${PY}" +repage "$CROP" 2>/dev/null || [[ ! -s "$CROP" ]]; then
    die "magick crop failed (${PW}x${PH}+${PX}+${PY})"
fi

wl-copy -t image/png < "$CROP" || die "wl-copy failed"
