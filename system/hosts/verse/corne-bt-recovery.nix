{ config, pkgs, lib, ... }:
# Self-healing for the Corne (ZMK) BLE keyboard's recurring bond-key desync.
#
# Background: roughly every 2-3 days the Corne and this host end up with
# mismatched LE long-term keys. The host keeps the device `Trusted=yes` but its
# bond file goes keyless (`[General]` only, no `[PeripheralLongTermKey]`), so
# BlueZ auto-connects on every advertisement, fails HID-over-GATT with ATT 0x0e
# ("read_pnpid_cb Error"), drops, and retries forever — a connect/disconnect
# loop. The documented ZMK/BlueZ remedy is a manual remove + re-pair, which
# costs ~30 min each time. There is no reliable Linux-side *prevention* (see
# FIXES.md 2026-06-14), so instead we make the failure self-heal in seconds.
#
# - corne-watch.service : tails the bluetooth journal for the desync signature
#                         and triggers recovery (debounced, rate-limited).
# - corne-recover.service: one-shot host-side remove + held-open re-pair, with
#                          semantic desktop notifications and a persistent event
#                          tally at /var/lib/corne-bt/events.log for diagnosis.
# - corne-fix           : manual command to trigger recovery on demand.
let
  mac = "C8:5B:C1:B5:9B:F3";

  recover = pkgs.writeShellScriptBin "corne-recover" ''
    # NOT set -e: bluetoothctl queries for optional interfaces legitimately
    # exit non-zero; -e would abort recovery mid-flight (see FIXES.md).
    set -uo pipefail
    export PATH=${lib.makeBinPath (with pkgs; [
      bluez coreutils gnugrep gawk systemd libnotify sudo util-linux
    ])}:$PATH

    MAC="${mac}"
    STATE=/var/lib/corne-bt
    EVENTS="$STATE/events.log"
    mkdir -p "$STATE"

    ts()    { date '+%Y-%m-%d %H:%M:%S'; }
    log()   { echo "[corne-recover] $*"; }            # -> journal
    event() { echo "$(ts) | $*" >>"$EVENTS"; }        # -> persistent tally

    # Notify every logged-in graphical user (root service -> user session bus).
    notify_user() {
      local title="$1" body="$2" urgency="''${3:-normal}" uid u
      for uid in $(loginctl list-users --no-legend | awk '{print $1}'); do
        u=$(id -un "$uid" 2>/dev/null) || continue
        sudo -u "$u" \
          DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
          notify-send -a "Corne BT" -u "$urgency" "$title" "$body" 2>/dev/null || true
      done
    }

    ADAPTER=$(bluetoothctl list 2>/dev/null | awk '/Controller/{print $2; exit}')
    info=$(bluetoothctl info "$MAC" 2>/dev/null)

    # Guard: if already healthy, do nothing (avoids needless re-pair if the
    # watcher fired on a transient that self-resolved).
    if grep -q "Bonded: yes" <<<"$info" && grep -q "ServicesResolved: yes" <<<"$info"; then
      log "Corne already healthy (bonded + services resolved); nothing to do."
      event "SKIP already-healthy"
      exit 0
    fi

    # --- Diagnostic snapshot BEFORE recovery (for future debugging) ---
    log "=== DESYNC DETECTED — snapshot ==="
    log "state: $(grep -E 'Paired|Bonded|Trusted|Connected' <<<"$info" | tr '\n' ' ')"
    sections="(no bond file)"
    bondfile="/var/lib/bluetooth/$ADAPTER/$MAC/info"
    if [ -f "$bondfile" ]; then
      sections=$(grep -oE '^\[[A-Za-z]+\]' "$bondfile" | tr '\n' ' ')
    fi
    log "bond file sections: $sections"
    hidfails=$(journalctl -u bluetooth --since "-5min" -o cat 2>/dev/null \
      | grep -c 'read_pnpid_cb\|HID Information read failed\|Report Reference descriptor failed' || true)
    log "HID-read failures (last 5min): $hidfails"
    event "DETECT bonded=$(grep -q 'Bonded: yes' <<<"$info" && echo yes || echo no) sections=[$sections] hidfails5m=$hidfails"

    notify_user "⚠ Corne BT desync detected" "Bond keys mismatched — auto-recovering…" critical

    # --- Recovery: remove + held-open re-pair (FIFO keeps the SMP session
    #     alive; a piped heredoc EOFs mid-pairing and leaves it unbonded). ---
    do_repair() {
      bluetoothctl remove "$MAC" >/dev/null 2>&1
      sleep 1
      bluetoothctl --timeout 12 scan on >/dev/null 2>&1
      if ! bluetoothctl devices 2>/dev/null | grep -qi "$MAC"; then
        log "device not advertising after remove (keyboard asleep?)"
        return 2
      fi
      local fifo; fifo=$(mktemp -u /tmp/cornefifo.XXXXXX); mkfifo "$fifo"
      bluetoothctl <"$fifo" >/dev/null 2>&1 &
      local btpid=$!
      exec 3>"$fifo"        # hold write end open so bluetoothctl never sees EOF
      printf 'default-agent\n' >&3
      printf 'pair %s\n'   "$MAC" >&3
      sleep 15
      printf 'trust %s\n'  "$MAC" >&3
      sleep 2
      printf 'connect %s\n' "$MAC" >&3
      sleep 6
      printf 'quit\n' >&3
      exec 3>&-
      wait "$btpid" 2>/dev/null
      rm -f "$fifo"
      bluetoothctl info "$MAC" 2>/dev/null | grep -q "Bonded: yes"
    }

    log "attempt 1: host-only re-pair (no bluetoothd restart)"
    if do_repair; then
      log "recovered on attempt 1"
      event "RECOVERED attempt=1 host-only"
      notify_user "✓ Corne recovered" "Re-paired (no restart needed)."
      exit 0
    fi

    log "attempt 1 failed; restarting bluetoothd and retrying"
    systemctl restart bluetooth
    sleep 5
    if do_repair; then
      log "recovered on attempt 2 (after bluetoothd restart)"
      event "RECOVERED attempt=2 after-restart"
      notify_user "✓ Corne recovered" "Re-paired after bluetoothd restart."
      exit 0
    fi

    log "recovery FAILED — keyboard likely asleep or needs BT_CLR"
    event "FAILED both-attempts"
    notify_user "✗ Corne recovery failed" \
      "Wake the keyboard, press BT_CLR (num layer), then run: corne-fix" critical
    exit 1
  '';

  # Watch the bluetooth journal for the desync signature and trigger recovery.
  # Matches ONLY read_pnpid_cb errors (one per failed connect cycle), so a
  # threshold of 2 within the window means a genuine repeating loop, not a
  # single transient at boot. On this host only the Corne is a BLE HID device,
  # so these lines are unambiguous.
  watch = pkgs.writeShellScriptBin "corne-watch" ''
    set -uo pipefail
    export PATH=${lib.makeBinPath (with pkgs; [ systemd coreutils util-linux ])}:$PATH
    THRESH=2; WINDOW=120; COOLDOWN=120
    buf=()
    journalctl -f -n0 -u bluetooth -o cat 2>/dev/null | while IFS= read -r line; do
      case "$line" in
        *read_pnpid_cb*Error*)
          now=$(date +%s)
          buf+=("$now")
          new=()
          for t in "''${buf[@]}"; do [ $((now - t)) -le "$WINDOW" ] && new+=("$t"); done
          buf=("''${new[@]}")
          if [ "''${#buf[@]}" -ge "$THRESH" ]; then
            logger -t corne-watch "desync signature: ''${#buf[@]} HID-read failures within ''${WINDOW}s — triggering corne-recover"
            systemctl start corne-recover.service || true
            buf=()
            sleep "$COOLDOWN"
          fi
          ;;
      esac
    done
  '';

  corneFix = pkgs.writeShellScriptBin "corne-fix" ''
    set -uo pipefail
    echo "Triggering Corne BLE recovery…"
    sudo ${pkgs.systemd}/bin/systemctl start corne-recover.service || true
    echo "--- recovery log (this boot) ---"
    ${pkgs.systemd}/bin/journalctl -b -u corne-recover -n 60 --no-pager
    echo
    echo "Event history: /var/lib/corne-bt/events.log"
  '';
in
{
  environment.systemPackages = [ corneFix ];

  systemd.services.corne-recover = {
    description = "Recover Corne BLE keyboard from bond-key desync";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${recover}/bin/corne-recover";
      StateDirectory = "corne-bt";
    };
    # Rate-limit so a persistent failure can't thrash the radio.
    startLimitIntervalSec = 600;
    startLimitBurst = 4;
  };

  systemd.services.corne-watch = {
    description = "Watch for Corne BLE bond-desync signature and self-heal";
    wantedBy = [ "multi-user.target" ];
    after = [ "bluetooth.service" ];
    wants = [ "bluetooth.service" ];
    serviceConfig = {
      ExecStart = "${watch}/bin/corne-watch";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
