#!/usr/bin/env bash
# Waybar custom network module — continuous JSON output
# Shows: instantaneous wifi signal (dBm) + truncated SSID, with rich tooltip.
# Built to replace waybar's built-in network module which reports the smoothed
# nl80211 signal_avg — that EWMA gets stuck on long-lived connections.

set -euo pipefail

IFACE="${1:-wlo1}"

while true; do
  link=$(iw dev "$IFACE" link 2>/dev/null || true)

  if [ -z "$link" ] || [ "$link" = "Not connected." ]; then
    jq -cn \
      --arg text "󰖪 No Network" \
      --arg ttip "Disconnected" \
      '{text: $text, tooltip: $ttip, class: "disconnected"}'
  else
    ssid=$(awk -F': ' '/^\tSSID:/ {sub(/^[ \t]+/, "", $2); print $2; exit}' <<<"$link")
    signal=$(awk '/signal:/ {print $2; exit}' <<<"$link")
    txrate=$(awk -F': ' '/tx bitrate:/ {sub(/^[ \t]+/, "", $2); print $2; exit}' <<<"$link")
    freq=$(awk '/freq:/ {print $2; exit}' <<<"$link")
    short_ssid="${ssid:0:3}"
    text=$(printf " %s %sdBm" "$short_ssid" "$signal")
    ttip=$(printf "SSID: %s\nSignal: %s dBm\nFreq: %s MHz\nTX: %s" "$ssid" "$signal" "$freq" "$txrate")

    jq -cn \
      --arg text "$text" \
      --arg ttip "$ttip" \
      '{text: $text, tooltip: $ttip, class: "connected"}'
  fi

  sleep 0.5
done
