#!/usr/bin/env bash
# Waybar custom bluetooth module — continuous JSON output
# Bar: nf-fa-bluetooth + every connected device's alias:.3 + battery%(s).
# Split keyboards (e.g. Corne) expose TWO GATT Battery Level characteristics
# (central + proxied peripheral); both are shown as L/R (e.g. "Cor 85/83%").
# Queries BlueZ via D-Bus (busctl) — bluetoothctl's piped output is unreliable.

# NOT `set -e`: this is a resilient polling loop. BlueZ D-Bus queries for
# optional interfaces (e.g. Battery1) legitimately exit non-zero, and `grep`
# exits 1 when no devices are paired. Under `set -e`+pipefail those propagate
# and kill the script permanently (waybar won't respawn a dead continuous
# module), leaving the module blank for the rest of the session.
set -uo pipefail

# nf-fa-bluetooth-b (U+F294)
ICON_BT=$'\xef\x8a\x94'

extract_string() {
  # `busctl get-property` prints `s "value"` for string types; unwrap it.
  sed -E 's/^s "(.*)"$/\1/'
}

while true; do
  tree=$(busctl --system tree org.bluez 2>/dev/null)
  paths=$(grep -oE '/org/bluez/hci0/dev_[A-F0-9_]+$' <<<"$tree" | sort -u)

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

    # Collect battery percentages. Prefer GATT Battery Level (0x2a19)
    # characteristics: a split keyboard exposes one per half — central first
    # (left), then the proxied peripheral (right). Read the cached Value (gentle,
    # kept fresh by notifications) rather than forcing a BLE read each poll.
    # Fall back to org.bluez.Battery1 for classic devices (headsets, etc.).
    batts=""
    for ch in $(grep -oE "${path}/service[0-9a-f]+/char[0-9a-f]+$" <<<"$tree"); do
      uuid=$(busctl --system get-property org.bluez "$ch" \
        org.bluez.GattCharacteristic1 UUID 2>/dev/null | extract_string)
      case "$uuid" in
        00002a19*)
          # busctl prints "ay <count> <byte>..." — take the byte only when
          # count>=1 (an empty "ay 0" must NOT parse as 0). The cached Value is
          # empty right after a reconnect (until the first notification), so fall
          # back to an active ReadValue, which also warms the cache for next poll.
          v=$(busctl --system get-property org.bluez "$ch" \
            org.bluez.GattCharacteristic1 Value 2>/dev/null \
            | awk '$1=="ay" && $2>=1 {print $3}')
          [ -z "$v" ] && v=$(busctl --system call org.bluez "$ch" \
            org.bluez.GattCharacteristic1 ReadValue a{sv} 0 2>/dev/null \
            | awk '$1=="ay" && $2>=1 {print $3}')
          [ -n "$v" ] && batts="$batts $v"
          ;;
      esac
    done
    if [ -z "$batts" ]; then
      b1=$(busctl --system get-property org.bluez "$path" \
        org.bluez.Battery1 Percentage 2>/dev/null | awk '{print $2}')
      [ -n "$b1" ] && batts="$b1"
    fi

    short="${alias:0:3}"
    # shellcheck disable=SC2086
    set -- $batts
    if [ "$#" -eq 0 ]; then
      bar_pieces="$bar_pieces $short"
      tt_pieces+="$alias ($addr)"$'\n'
    elif [ "$#" -eq 1 ]; then
      bar_pieces="$bar_pieces $short ${1}%"
      tt_pieces+="$alias ($addr) — ${1}%"$'\n'
      [ "$1" -le 20 ] && low_battery=1
    else
      # Split keyboard: central/left first, peripheral/right second.
      bar_pieces="$bar_pieces $short ${1}/${2}%"
      tt_pieces+="$alias ($addr) — L ${1}% / R ${2}%"$'\n'
      { [ "$1" -le 20 ] || [ "$2" -le 20 ]; } && low_battery=1
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
