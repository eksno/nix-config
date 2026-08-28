#!/usr/bin/env bash
# Perceptual brightness control that rolls over into gamma past the panel max.
#
#   brightness.sh up | down | get
#
# Two ranges, stitched into one continuous control:
#
#   backlight 1..max   real light output. On this panel max_brightness is
#                      literally nits (EDID: 400 cd/m^2 full-coverage), and the
#                      scale is LINEAR in nits while perception is roughly
#                      logarithmic — so fixed percent-of-max steps feel huge at
#                      the bottom and invisible at the top. We step
#                      geometrically instead (x1.15) for even-feeling changes.
#
#   gamma 100..200%    hyprsunset lifts midtones once the backlight is maxed.
#                      This does NOT raise peak white (the panel is already
#                      emitting all it can; on OLED that ceiling is ABL), it
#                      just makes everything below white brighter. Costs
#                      contrast and colour accuracy — upstream says so plainly.
#
# Gamma has no "get" in hyprsunset's IPC, so we track it in $XDG_RUNTIME_DIR,
# which is wiped each boot — matching the fact that gamma resets whenever the
# hyprsunset daemon exits.
set -u

STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-brightness-gamma"
GAMMA_MIN=100
GAMMA_MAX=200
GAMMA_STEP=10
FACTOR_NUM=115   # 1.15x per step
FACTOR_DEN=100

gamma_get() { cat "$STATE" 2>/dev/null || echo "$GAMMA_MIN"; }

gamma_set() {
  local g=$1
  (( g < GAMMA_MIN )) && g=$GAMMA_MIN
  (( g > GAMMA_MAX )) && g=$GAMMA_MAX
  if hyprctl hyprsunset gamma "$g" >/dev/null 2>&1; then
    echo "$g" > "$STATE"
  else
    # daemon not up — keep state honest rather than lying about the level
    echo "$GAMMA_MIN" > "$STATE"
    return 1
  fi
}

cur=$(brightnessctl get 2>/dev/null || echo 0)
max=$(brightnessctl max 2>/dev/null || echo 0)
gamma=$(gamma_get)

case "${1:-}" in
  up)
    if (( cur >= max )); then
      gamma_set $(( gamma + GAMMA_STEP ))
    else
      new=$(( cur * FACTOR_NUM / FACTOR_DEN ))
      (( new <= cur )) && new=$(( cur + 1 ))   # guarantee progress at low values
      (( new > max )) && new=$max
      brightnessctl -q set "$new"
    fi
    ;;
  down)
    if (( gamma > GAMMA_MIN )); then
      gamma_set $(( gamma - GAMMA_STEP ))
    else
      new=$(( cur * FACTOR_DEN / FACTOR_NUM ))
      (( new >= cur )) && new=$(( cur - 1 ))
      (( new < 1 )) && new=1                    # never fully dark
      brightnessctl -q set "$new"
    fi
    ;;
  get)
    printf 'backlight %s/%s (%s%%)  gamma %s%%\n' \
      "$cur" "$max" "$(( max > 0 ? cur * 100 / max : 0 ))" "$gamma"
    ;;
  *)
    echo "usage: $(basename "$0") up|down|get" >&2
    exit 1
    ;;
esac
