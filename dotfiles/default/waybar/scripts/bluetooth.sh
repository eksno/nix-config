#!/usr/bin/env bash
# Waybar custom bluetooth module — continuous JSON output
# Bar: nf-fa-bluetooth + every connected device's alias:.3 + battery%, side-by-side.
# Tooltip: full alias / MAC / battery for each connected device.
# Queries BlueZ via D-Bus (busctl) — bluetoothctl's piped output is unreliable.

set -euo pipefail

# nf-fa-bluetooth-b (U+F294)
ICON_BT=$'\xef\x8a\x94'

extract_string() {
  # `busctl get-property` prints `s "value"` for string types; unwrap it.
  sed -E 's/^s "(.*)"$/\1/'
}

while true; do
  paths=$(busctl --system tree org.bluez 2>/dev/null \
    | grep -oE '/org/bluez/hci0/dev_[A-F0-9_]+$' \
    | sort -u)

  bar_pieces=""
  tt_pieces=""
  count=0
  low_battery=0

  while IFS= read -r path; do
    [ -z "$path" ] && continue

    conn=$(busctl --system get-property org.bluez "$path" \
      org.bluez.Device1 Connected 2>/dev/null | awk '{print $2}')
    [ "$conn" != "true" ] && continue

    alias=$(busctl --system get-property org.bluez "$path" \
      org.bluez.Device1 Alias 2>/dev/null | extract_string)
    addr=$(busctl --system get-property org.bluez "$path" \
      org.bluez.Device1 Address 2>/dev/null | extract_string)
    battery=$(busctl --system get-property org.bluez "$path" \
      org.bluez.Battery1 Percentage 2>/dev/null | awk '{print $2}')

    short="${alias:0:3}"
    if [ -n "$battery" ]; then
      bar_pieces="$bar_pieces $short ${battery}%"
      tt_pieces+="$alias ($addr) — ${battery}%"$'\n'
      [ "$battery" -le 20 ] && low_battery=1
    else
      bar_pieces="$bar_pieces $short"
      tt_pieces+="$alias ($addr)"$'\n'
    fi
    count=$((count + 1))
  done <<<"$paths"

  if [ "$count" -eq 0 ]; then
    powered=$(busctl --system get-property org.bluez /org/bluez/hci0 \
      org.bluez.Adapter1 Powered 2>/dev/null | awk '{print $2}')
    if [ "$powered" = "true" ]; then
      text="$ICON_BT"
      tt="Bluetooth on, no devices connected"
      cls="on"
    else
      text="$ICON_BT off"
      tt="Bluetooth off"
      cls="off"
    fi
  else
    text="$ICON_BT$bar_pieces"
    tt="${tt_pieces%$'\n'}"
    cls="connected"
    [ "$low_battery" -eq 1 ] && cls="warning"
  fi

  jq -cn --arg t "$text" --arg tt "$tt" --arg c "$cls" \
    '{text:$t, tooltip:$tt, class:$c}'

  sleep 5
done
