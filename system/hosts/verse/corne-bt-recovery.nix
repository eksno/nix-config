{ config, pkgs, lib, ... }:
# Self-healing for the Corne (ZMK) BLE keyboard's recurring bond-key desync.
#
# Background: roughly every 2-3 days the Corne and this host end up unable to
# establish an encrypted link. BlueZ auto-connects, HID-over-GATT fails with
# ATT 0x0e ("read_pnpid_cb Error"), drops, retries — a connect/disconnect loop.
# The documented ZMK/BlueZ remedy is a manual remove + re-pair (~30 min). There
# is no reliable Linux-side *prevention* (FIXES.md 2026-06-14), so we self-heal.
#
# SAFETY (learned the hard way — see FIXES.md 2026-06-15): recovery must NEVER
# destroy a bond blindly. The failure has three shapes:
#   A) host bond keyless (no LTK) + keyboard advertising pairable → remove +
#      re-pair works host-side, hands-free.
#   B) BOTH sides bonded but keys mismatch → host-only re-pair canNOT fix it;
#      the keyboard must clear its own bond with `&bt BT_CLR` first. Removing the
#      host bond here doesn't help and isn't done automatically.
#   C) keyboard simply asleep/out-of-range (bond perfectly valid) → do NOTHING.
# So corne-recover gates every destructive step on: healthy? → gentle reconnect
# (non-destructive) → present at all? → only then, and only for keyless bonds
# (or an explicit manual --force), remove + re-pair.
#
# - corne-watch.service : tails the bluetooth journal for the desync signature
#                         and triggers corne-recover (auto/safe mode).
# - corne-recover.service: the self-heal (auto mode: keyless-only remove).
# - corne-fix           : manual `corne-recover --force` (you're present to
#                         press BT_CLR), with live output.
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

    MODE="auto"
    [ "''${1:-}" = "--force" ] && MODE="force"

    ts()    { date '+%Y-%m-%d %H:%M:%S'; }
    log()   { echo "[corne-recover] $*"; }            # -> journal / terminal
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

    read_info() { bluetoothctl info "$MAC" 2>/dev/null; }
    healthy()   { local i; i=$(read_info); grep -q "Connected: yes" <<<"$i" && grep -q "ServicesResolved: yes" <<<"$i"; }
    bond_has_ltk() {
      local f="/var/lib/bluetooth/$ADAPTER/$MAC/info"
      [ -f "$f" ] && grep -qE '^\[(PeripheralLongTermKey|SlaveLongTermKey|LongTermKey)\]' "$f"
    }
    # Presence = the keyboard is advertising / in range right now (fresh RSSI
    # after a scan). This is the gate that prevents destroying a valid bond just
    # because the keyboard is asleep.
    present() {
      bluetoothctl --timeout 10 scan on >/dev/null 2>&1
      read_info | grep -qE '^[[:space:]]*RSSI:'
    }

    info=$(read_info)
    log "=== corne-recover ($MODE) ==="
    log "state: $(grep -E 'Paired|Bonded|Trusted|Connected' <<<"$info" | tr '\n' ' ')"

    # 1. Already healthy → nothing to do.
    if healthy; then
      log "Corne healthy (connected + services resolved); nothing to do."
      event "SKIP healthy"
      exit 0
    fi

    # 2. Gentle, NON-destructive reconnect first (fixes transients without
    #    touching the bond). Only meaningful if a bond exists.
    if grep -q "Bonded: yes" <<<"$info"; then
      log "gentle reconnect attempt (non-destructive)…"
      timeout 15 bluetoothctl connect "$MAC" >/dev/null 2>&1 || true
      if healthy; then
        log "recovered via plain reconnect — bond preserved."
        event "RECOVERED gentle-connect"
        notify_user "✓ Corne reconnected" "Link restored without re-pairing."
        exit 0
      fi
    fi

    # 3. PRESENCE GATE — never destroy a bond when the keyboard isn't in range.
    #    (Asleep/off keyboard with a valid bond = case C: leave it alone.)
    if ! present; then
      log "Corne not advertising / out of range — leaving bond intact, nothing to do."
      event "NOOP not-present (bond preserved)"
      [ "$MODE" = "force" ] && notify_user "Corne not in range" \
        "Asleep or off — nothing to recover; bond left intact." low
      exit 0
    fi

    # 4. Present but unhealthy = a genuine desync. Decide how aggressive to be.
    keyless=no; bond_has_ltk || keyless=yes
    hidfails=$(journalctl -u bluetooth --since "-5min" -o cat 2>/dev/null \
      | grep -c 'read_pnpid_cb\|HID Information read failed\|Report Reference descriptor failed' || true)
    log "desync confirmed (present + unhealthy); host bond keyless=$keyless, HID-read failures(5m)=$hidfails"
    event "DETECT present=yes keyless=$keyless mode=$MODE hidfails5m=$hidfails"

    if [ "$keyless" = "no" ] && [ "$MODE" = "auto" ]; then
      # Case B: full host bond intact but link failing → both sides bonded with
      # mismatched keys. Host-side remove canNOT fix this without `&bt BT_CLR` on
      # the keyboard, and the bond may still be salvageable — do NOT auto-destroy.
      log "full host bond intact but link failing → needs keyboard BT_CLR; not auto-removing."
      event "DEFER mode-B needs-BT_CLR (bond preserved, no auto-remove)"
      notify_user "⚠ Corne desync (bond intact)" \
        "Press BT_CLR (hold GUI thumb + ' key), then run: corne-fix" critical
      exit 0
    fi

    # Case A (keyless host bond → nothing to lose) OR manual --force (user is
    # present and will press BT_CLR): remove + held-open re-pair. The FIFO keeps
    # the SMP session alive; a piped heredoc EOFs mid-pairing and leaves it
    # unbonded.
    do_repair() {
      bluetoothctl remove "$MAC" >/dev/null 2>&1
      sleep 1
      bluetoothctl --timeout 12 scan on >/dev/null 2>&1
      if ! bluetoothctl devices 2>/dev/null | grep -qi "$MAC"; then
        log "device stopped advertising before pair"
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

    notify_user "⚠ Corne desync detected" "Re-pairing… (keyless=$keyless, mode=$MODE)" critical

    log "attempt 1: remove + re-pair (no bluetoothd restart)"
    if do_repair; then
      log "recovered on attempt 1"
      event "RECOVERED attempt=1 keyless=$keyless mode=$MODE"
      notify_user "✓ Corne recovered" "Re-paired and bonded."
      exit 0
    fi

    log "attempt 1 failed; restarting bluetoothd and retrying"
    systemctl restart bluetooth
    sleep 5
    if do_repair; then
      log "recovered on attempt 2 (after bluetoothd restart)"
      event "RECOVERED attempt=2 after-restart keyless=$keyless mode=$MODE"
      notify_user "✓ Corne recovered" "Re-paired after bluetoothd restart."
      exit 0
    fi

    # Re-pair couldn't bond → keyboard still holds its own bond (case B without a
    # BT_CLR). Tell the user; the host bond is already gone but it was broken.
    log "recovery FAILED — keyboard would not bond (press BT_CLR then retry)"
    event "FAILED needs-BT_CLR keyless=$keyless mode=$MODE"
    notify_user "✗ Corne recovery failed" \
      "Keyboard would not bond. Press BT_CLR (hold GUI thumb + ' key), then run: corne-fix" critical
    exit 1
  '';

  # Watch the bluetooth journal for the desync signature and trigger recovery
  # in AUTO mode (which only removes keyless bonds — see corne-recover). Matches
  # ONLY read_pnpid_cb errors (one per failed connect cycle), so 2 within the
  # window means a genuine repeating loop, not a single transient. On this host
  # only the Corne is a BLE HID device, so these lines are unambiguous.
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
            logger -t corne-watch "desync signature: ''${#buf[@]} HID-read failures within ''${WINDOW}s — triggering corne-recover (auto)"
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
    echo "Triggering Corne BLE recovery (manual / --force)…"
    sudo ${recover}/bin/corne-recover --force
    echo
    echo "Event history: /var/lib/corne-bt/events.log"
  '';

  # Battery-health logger: while the Corne is connected, sample the reported
  # BLE battery % every 2 min into /var/lib/corne-bt/battery.log. A healthy Corne
  # half loses a few % per DAY; a failing cell craters %/hour and browns out the
  # radio under TX load (the suspected cause of the recurring bond desync).
  batteryDev = "/org/bluez/hci0/dev_C8_5B_C1_B5_9B_F3";
  batteryLog = pkgs.writeShellScriptBin "corne-battery-log" ''
    set -uo pipefail
    export PATH=${lib.makeBinPath (with pkgs; [ systemd coreutils gawk ])}:$PATH
    DEV="${batteryDev}"
    STATE=/var/lib/corne-bt
    LOG="$STATE/battery.log"
    mkdir -p "$STATE"
    while true; do
      conn=$(busctl --system get-property org.bluez "$DEV" \
        org.bluez.Device1 Connected 2>/dev/null | awk '{print $2}')
      if [ "$conn" = "true" ]; then
        pct=$(busctl --system get-property org.bluez "$DEV" \
          org.bluez.Battery1 Percentage 2>/dev/null | awk '{print $2}')
        [ -z "$pct" ] && pct="?"
        echo "$(date '+%Y-%m-%d %H:%M:%S') | $pct | connected" >>"$LOG"
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') | - | disconnected" >>"$LOG"
      fi
      sleep 120
    done
  '';

  # corne-battery: show recent samples + estimate drain rate.
  batteryView = pkgs.writeShellScriptBin "corne-battery" ''
    set -uo pipefail
    export PATH=${lib.makeBinPath (with pkgs; [ coreutils gnugrep gawk findutils ])}:$PATH
    LOG=/var/lib/corne-bt/battery.log
    if [ ! -f "$LOG" ]; then
      echo "No battery log yet ($LOG)."
      echo "It records while the Corne is connected over Bluetooth."
      exit 0
    fi
    echo "Recent samples (timestamp | battery% | link):"
    tail -n 25 "$LOG"
    echo
    first=$(grep -E '\| [0-9]+ \| connected' "$LOG" | head -1)
    last=$(grep  -E '\| [0-9]+ \| connected' "$LOG" | tail -1)
    if [ -n "$first" ] && [ -n "$last" ] && [ "$first" != "$last" ]; then
      ft=$(echo "$first" | cut -d'|' -f1 | xargs); fp=$(echo "$first" | cut -d'|' -f2 | xargs)
      lt=$(echo "$last"  | cut -d'|' -f1 | xargs); lp=$(echo "$last"  | cut -d'|' -f2 | xargs)
      fe=$(date -d "$ft" +%s 2>/dev/null || echo 0)
      le=$(date -d "$lt" +%s 2>/dev/null || echo 0)
      echo "Span: $fp% ($ft)  →  $lp% ($lt)"
      if [ "$le" -gt "$fe" ] && [ "$fp" -gt "$lp" ]; then
        awk -v d="$((fp - lp))" -v s="$((le - fe))" 'BEGIN{
          printf "Drain: %.1f%%/hour over %.1fh.  (Healthy: a few %%/DAY. >2-3%%/hour = failing cell.)\n", d/(s/3600), s/3600 }'
      else
        echo "(no net drain in window yet — was it charging / freshly bonded?)"
      fi
    fi
  '';

  # Suspend/resume hooks. The desync trigger is the BLE link tearing down on
  # laptop suspend (mornings) or keyboard idle. Disconnect the Corne cleanly
  # before sleep (so it isn't dropped mid-transaction), and nudge a
  # non-destructive reconnect on resume. Both stamp /var/lib/corne-bt/events.log
  # so desyncs/battery drain can be correlated with wake events. Nothing here
  # removes a bond — recovery stays the watcher/corne-recover's job.
  suspendHook = pkgs.writeShellScript "corne-pre-suspend" ''
    export PATH=${lib.makeBinPath (with pkgs; [ bluez coreutils ])}:$PATH
    mkdir -p /var/lib/corne-bt
    echo "$(date '+%Y-%m-%d %H:%M:%S') | SUSPEND (clean-disconnect Corne)" >>/var/lib/corne-bt/events.log
    bluetoothctl disconnect ${mac} >/dev/null 2>&1 || true
  '';
  resumeHook = pkgs.writeShellScript "corne-post-resume" ''
    export PATH=${lib.makeBinPath (with pkgs; [ bluez coreutils ])}:$PATH
    mkdir -p /var/lib/corne-bt
    echo "$(date '+%Y-%m-%d %H:%M:%S') | RESUME (nudge reconnect)" >>/var/lib/corne-bt/events.log
    sleep 4   # let the BT controller re-initialise before reconnecting
    bluetoothctl connect ${mac} >/dev/null 2>&1 || true
  '';
in
{
  environment.systemPackages = [ corneFix batteryView ];

  # `lines` type → these merge with power-mode's resumeCommands, not clobber it.
  powerManagement.powerDownCommands = "${suspendHook}";
  powerManagement.resumeCommands = "${resumeHook}";

  systemd.services.corne-recover = {
    description = "Recover Corne BLE keyboard from bond-key desync (auto/safe)";
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

  systemd.services.corne-battery-log = {
    description = "Log Corne BLE battery % over time (battery-health diagnosis)";
    wantedBy = [ "multi-user.target" ];
    after = [ "bluetooth.service" ];
    wants = [ "bluetooth.service" ];
    serviceConfig = {
      ExecStart = "${batteryLog}/bin/corne-battery-log";
      Restart = "always";
      RestartSec = 10;
      StateDirectory = "corne-bt";
    };
  };
}
