#!/usr/bin/env bash
# Interactive region screenshot to clipboard.
#
# Why this exists: on Hyprland 0.54.x with fractional scaling, both `grim`
# and `wayshot -g` are broken. `grim` returns "supplied geometry did not
# intersect with any outputs" (and even bare `grim FILE` produces a
# zero-width PNG), and `wayshot -g`/`wayshot --clipboard` (no -o) crash
# with `wp_viewport: Size was <= 0`. The only thing that reliably works
# is `wayshot -o <name>` which captures a single output at physical pixel
# resolution. So we slurp a region (in logical coords), capture the full
# output it lives on, and crop with ImageMagick.
#
# See FIXES.md entry "hypr-screenshot-fractional-scaling" for the saga.

set -euo pipefail

# Slurp returns: output-relative X Y, width, height, output name.
# %X/%Y are relative to the top-left of the output containing the selection.
read -r X Y W H OUT < <(slurp -f '%X %Y %w %h %o') || exit 0

if [[ -z "${OUT:-}" || "$OUT" == "<unknown>" ]]; then
    notify-send "Screenshot" "Could not determine output for selection" -u critical
    exit 1
fi

# Slurp's coordinates are in logical (compositor) space; wayshot captures
# at physical pixels. Multiply by the output's scale to get buffer coords.
SCALE=$(hyprctl monitors -j | jq -r --arg name "$OUT" '.[] | select(.name==$name) | .scale')
if [[ -z "$SCALE" || "$SCALE" == "null" ]]; then
    notify-send "Screenshot" "Could not read scale for $OUT" -u critical
    exit 1
fi

# Round to integer pixels.
PX=$(awk -v v="$X" -v s="$SCALE" 'BEGIN { printf "%.0f", v * s }')
PY=$(awk -v v="$Y" -v s="$SCALE" 'BEGIN { printf "%.0f", v * s }')
PW=$(awk -v v="$W" -v s="$SCALE" 'BEGIN { printf "%.0f", v * s }')
PH=$(awk -v v="$H" -v s="$SCALE" 'BEGIN { printf "%.0f", v * s }')

wayshot -o "$OUT" - 2>/dev/null \
    | magick - -crop "${PW}x${PH}+${PX}+${PY}" +repage png:- \
    | wl-copy -t image/png
