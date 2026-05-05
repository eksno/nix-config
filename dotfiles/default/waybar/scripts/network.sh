#!/usr/bin/env bash
# Waybar custom network module — continuous JSON output
# Bar: nf-fa-wifi + truncated SSID + instantaneous signal (dBm).
# Tooltip: link rate, throughput, retries/s, beacon loss, signal avg —
# enough to answer "why is wifi slow right now?" at a glance.

set -euo pipefail

IFACE="${1:-wlo1}"

format_secs() {
  local s=$1
  local h=$((s / 3600))
  local m=$(((s % 3600) / 60))
  local sec=$((s % 60))
  if [ "$h" -gt 0 ]; then printf "%dh %dm" "$h" "$m"
  elif [ "$m" -gt 0 ]; then printf "%dm %ds" "$m" "$sec"
  else printf "%ds" "$sec"
  fi
}

# Format bytes/sec → human-readable rate (bits/sec).
fmt_rate() {
  local bps=$(( $1 * 8 ))
  if   [ "$bps" -ge 1000000000 ]; then awk -v v="$bps" 'BEGIN{printf "%.1f Gbps", v/1e9}'
  elif [ "$bps" -ge 1000000 ];    then awk -v v="$bps" 'BEGIN{printf "%.1f Mbps", v/1e6}'
  elif [ "$bps" -ge 1000 ];       then awk -v v="$bps" 'BEGIN{printf "%.1f kbps", v/1e3}'
  else                                  printf "%d bps" "$bps"
  fi
}

LAST_RETRIES="" LAST_FAILED="" LAST_BLOSS="" LAST_RX="" LAST_TX="" LAST_TS=""

while true; do
  link=$(iw dev "$IFACE" link 2>/dev/null || true)
  now=$(date +%s.%N)

  if [ -z "$link" ] || [ "$link" = "Not connected." ]; then
    jq -cn --arg t "󰖪 No Network" --arg tt "Disconnected" \
      '{text:$t, tooltip:$tt, class:"disconnected"}'
    LAST_RETRIES="" LAST_FAILED="" LAST_BLOSS="" LAST_RX="" LAST_TX="" LAST_TS=""
    sleep 0.5
    continue
  fi

  # --- iw link: SSID / BSSID / freq / current signal ---
  ssid=$(awk -F':[ \t]+' '/^\tSSID:/{sub(/^[ \t]+/,"",$2);print $2;exit}' <<<"$link")
  bssid=$(awk '/^Connected to/{print $3;exit}' <<<"$link")
  freq=$(awk '/freq:/{print $2;exit}' <<<"$link")
  signal=$(awk '/signal:/{print $2;exit}' <<<"$link")

  # --- iw station dump: rates + counters ---
  st=$(iw dev "$IFACE" station dump 2>/dev/null || true)
  sig_avg=$(awk -F':[ \t]+' '/signal avg:/{sub(/^[ \t]+/,"",$2);print $2;exit}' <<<"$st")
  bcn_avg=$(awk -F':[ \t]+' '/beacon signal avg:/{sub(/^[ \t]+/,"",$2);print $2;exit}' <<<"$st")
  txrate=$(awk -F':[ \t]+' '/tx bitrate:/{sub(/^[ \t]+/,"",$2);print $2;exit}' <<<"$st")
  rxrate=$(awk -F':[ \t]+' '/rx bitrate:/{sub(/^[ \t]+/,"",$2);print $2;exit}' <<<"$st")
  retries=$(awk '/tx retries:/{print $3;exit}' <<<"$st")
  failed=$(awk '/tx failed:/{print $3;exit}' <<<"$st")
  bloss=$(awk '/beacon loss:/{print $3;exit}' <<<"$st")
  rxdrop=$(awk '/rx drop misc:/{print $4;exit}' <<<"$st")
  rx_bytes=$(awk '/rx bytes:/{print $3;exit}' <<<"$st")
  tx_bytes=$(awk '/tx bytes:/{print $3;exit}' <<<"$st")
  conn_t=$(awk '/connected time:/{print $3;exit}' <<<"$st")
  inactive=$(awk '/inactive time:/{print $3;exit}' <<<"$st")

  # --- Compute deltas / rates over the previous tick ---
  rate_line=""; retries_line=""; failed_line=""; bloss_line=""
  if [ -n "$LAST_TS" ] && [ -n "$retries" ]; then
    dt=$(awk -v a="$now" -v b="$LAST_TS" 'BEGIN{d=a-b; if(d<0.05)d=0.05; print d}')
    d_retries=$(( retries - LAST_RETRIES ))
    d_failed=$(( failed  - LAST_FAILED  ))
    d_bloss=$((  bloss   - LAST_BLOSS   ))
    d_rx=$(( rx_bytes - LAST_RX ))
    d_tx=$(( tx_bytes - LAST_TX ))
    rx_bps=$(awk -v v="$d_rx" -v t="$dt" 'BEGIN{printf "%d", v/t}')
    tx_bps=$(awk -v v="$d_tx" -v t="$dt" 'BEGIN{printf "%d", v/t}')
    retries_ps=$(awk -v v="$d_retries" -v t="$dt" 'BEGIN{printf "%.1f", v/t}')
    failed_ps=$(awk -v v="$d_failed" -v t="$dt" 'BEGIN{printf "%.1f", v/t}')
    bloss_ps=$(awk -v v="$d_bloss" -v t="$dt" 'BEGIN{printf "%.1f", v/t}')
    rate_line=$(printf "Throughput: ↑ %s  ↓ %s" "$(fmt_rate "$tx_bps")" "$(fmt_rate "$rx_bps")")
    retries_line=$(printf "TX retries: %s (+%s/s)" "$retries" "$retries_ps")
    failed_line=$(printf "TX failed: %s (+%s/s)" "$failed" "$failed_ps")
    bloss_line=$(printf "Beacon loss: %s (+%s/s)" "$bloss" "$bloss_ps")
  fi
  LAST_TS=$now LAST_RETRIES=$retries LAST_FAILED=$failed LAST_BLOSS=$bloss
  LAST_RX=$rx_bytes LAST_TX=$tx_bytes

  # --- Bar text ---
  short_ssid="${ssid:0:3}"
  text=$(printf $' %s %sdBm' "$short_ssid" "$signal")

  # --- Tooltip ---
  tt="SSID: $ssid"
  [ -n "$bssid" ] && tt+=$'\n'"BSSID: $bssid"
  tt+=$'\n'"Signal: ${signal} dBm  (avg ${sig_avg:-?}, beacon ${bcn_avg:-?})"
  tt+=$'\n'"Freq: ${freq} MHz"
  [ -n "$txrate" ] && tt+=$'\n'"Link TX: $txrate"
  [ -n "$rxrate" ] && tt+=$'\n'"Link RX: $rxrate"
  [ -n "$rate_line" ] && tt+=$'\n'"$rate_line"
  [ -n "$retries_line" ] && tt+=$'\n'"$retries_line"
  [ -n "$failed_line" ] && tt+=$'\n'"$failed_line"
  [ -n "$bloss_line" ] && tt+=$'\n'"$bloss_line"
  [ -n "${rxdrop:-}" ] && tt+=$'\n'"RX drop misc: $rxdrop"
  [ -n "${inactive:-}" ] && tt+=$'\n'"Inactive: ${inactive} ms"
  [ -n "${conn_t:-}" ] && tt+=$'\n'"Connected: $(format_secs "$conn_t")"

  jq -cn --arg t "$text" --arg tt "$tt" \
    '{text:$t, tooltip:$tt, class:"connected"}'

  sleep 0.5
done
