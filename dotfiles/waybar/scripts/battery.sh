#!/usr/bin/env bash
# Waybar custom battery module — continuous JSON output
# Shows: battery %, avg watts (20s rolling), estimated time, power-mode level

set -euo pipefail

BAT=""
for b in /sys/class/power_supply/BAT*; do
  [ -f "$b/energy_now" ] && BAT="$b" && break
done
if [ -z "$BAT" ]; then
  echo '{"text": "no battery", "tooltip": "No battery found"}'
  exit 0
fi

SAMPLES=()
WINDOW=200

level_name() {
  case "$1" in
    0) echo "perf" ;;
    2) echo "bal" ;;
    4) echo "save" ;;
    10) echo "emer" ;;
    *) echo "L$1" ;;
  esac
}

while true; do
  power_uw=$(cat "$BAT/power_now" 2>/dev/null || echo 0)
  energy_uw=$(cat "$BAT/energy_now" 2>/dev/null || echo 0)
  capacity=$(cat "$BAT/capacity" 2>/dev/null || echo 0)
  status=$(cat "$BAT/status" 2>/dev/null || echo "Unknown")

  # Add sample to rolling window
  SAMPLES+=("$power_uw")
  if [ ${#SAMPLES[@]} -gt $WINDOW ]; then
    SAMPLES=("${SAMPLES[@]:1}")
  fi

  # Compute rolling average
  sum=0
  for s in "${SAMPLES[@]}"; do
    sum=$((sum + s))
  done
  avg_uw=$((sum / ${#SAMPLES[@]}))
  avg_w=$(awk "BEGIN { printf \"%.1f\", $avg_uw / 1000000 }")

  # Time estimate
  time_str=""
  if [ "$status" = "Discharging" ] && [ "$avg_uw" -gt 0 ]; then
    total_min=$(awk "BEGIN { printf \"%d\", ($energy_uw / $avg_uw) * 60 }")
    h=$((total_min / 60))
    m=$((total_min % 60))
    time_str=$(printf "%dh%02dm" "$h" "$m")
  elif [ "$status" = "Charging" ] && [ "$avg_uw" -gt 0 ]; then
    full_uw=$(cat "$BAT/energy_full" 2>/dev/null || echo "$energy_uw")
    remaining=$((full_uw - energy_uw))
    if [ "$remaining" -gt 0 ]; then
      total_min=$(awk "BEGIN { printf \"%d\", ($remaining / $avg_uw) * 60 }")
      h=$((total_min / 60))
      m=$((total_min % 60))
      time_str=$(printf "%dh%02dm full" "$h" "$m")
    fi
  fi

  # Power-mode level
  level="0"
  [ -f /tmp/power-mode/current-level ] && level=$(cat /tmp/power-mode/current-level 2>/dev/null || echo "0")
  lname=$(level_name "$level")

  # Battery icon
  if [ "$status" = "Charging" ]; then
    icon=""
  elif [ "$capacity" -ge 90 ]; then icon=""
  elif [ "$capacity" -ge 80 ]; then icon=""
  elif [ "$capacity" -ge 70 ]; then icon=""
  elif [ "$capacity" -ge 60 ]; then icon=""
  elif [ "$capacity" -ge 50 ]; then icon=""
  elif [ "$capacity" -ge 40 ]; then icon=""
  elif [ "$capacity" -ge 30 ]; then icon=""
  elif [ "$capacity" -ge 20 ]; then icon=""
  elif [ "$capacity" -ge 10 ]; then icon=""
  else icon=""
  fi

  # CSS class for styling
  if [ "$status" = "Charging" ]; then
    class="charging"
  elif [ "$capacity" -le 15 ]; then
    class="critical"
  elif [ "$capacity" -le 30 ]; then
    class="warning"
  else
    class="discharging"
  fi

  # Build display text
  text="${capacity}% ${avg_w}W"
  [ -n "$time_str" ] && text="${text} ~${time_str}"
  text="${text} ${lname}"

  avg_secs=$(awk "BEGIN { printf \"%.0f\", ${#SAMPLES[@]} * 0.1 }")
  tooltip="Battery: ${capacity}%\\nPower: ${avg_w}W (${avg_secs}s avg)\\nStatus: ${status}\\nPower Mode: level ${level} (${lname})\\nEstimate: ${time_str:-N/A}"

  printf '{"text": "%s %s", "tooltip": "%s", "class": "%s", "percentage": %d}\n' \
    "$icon" "$text" "$tooltip" "$class" "$capacity"

  sleep 0.1
done
