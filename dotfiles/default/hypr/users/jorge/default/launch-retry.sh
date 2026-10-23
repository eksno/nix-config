#!/bin/sh
# launch-retry.sh [--attempt N] [--ws "RULE"] <window-class> <cmd...>
#
# Startup launcher for the Chromium apps (Chrome, Discord). Since 2026-10-15
# they come up running but windowless on every login when exec'd 2-3s after
# Hyprland starts. A kill + relaunch minutes later always maps a window, but
# the 2026-10-23 login showed that a relaunch ~33s after login is ALSO
# windowless (Discord's krisp log: init at 15:17:14, killed, init again at
# 15:17:42, still no window until a manual relaunch at 15:34). So:
#   1. gate: monitor present, xdg-desktop-portal active and answering, secret
#      service answering, monitor topology (mirror/position) unchanged for 3s
#      (the glasses-mirror watcher re-applies hl.monitor at T+0/2/5),
#   2. exec the app (keeps the pid Hyprland bound the workspace rule to),
#   3. a detached watchdog checks for a window of <class> after 30s; if none,
#      logs diagnostics, kills the app's process tree and asks Hyprland to run
#      this script again with --attempt N+1 (same workspace rule). Attempts are
#      spaced 15s, 45s, 120s apart; four attempts max.
#   4. attempt 1 runs with WAYLAND_DEBUG=client, stderr captured (30MB cap) to
#      ~/.cache/launch-retry-<class>.wl.log, to see where the handshake stops.
# Log: ~/.cache/launch-retry.log
attempt=1; ws=""
while :; do
  case "$1" in
    --attempt) attempt=$2; shift 2 ;;
    --ws)      ws=$2;      shift 2 ;;
    --watch)   shift; mode=watch; break ;;
    *) break ;;
  esac
done
self=$0
cache=/home/jorge/.cache
log=$cache/launch-retry.log
say() { printf '%s %s#%s[%s]: %s\n' "$(date +%T)" "$cls" "$attempt" "$$" "$*" >>"$log"; }
has_window() { hyprctl clients -j 2>/dev/null | grep -qE "\"class\": *\"$cls\""; }
mon_sig() { hyprctl monitors all -j 2>/dev/null | grep -E '"(description|mirrorOf|x|y|disabled|dpmsStatus)"' | tr -d ' \t\n'; }
tree() { echo "$1"; for c in $(ps -o pid= --ppid "$1" 2>/dev/null); do tree "$c"; done; }

# ---------------------------------------------------------------- watchdog
if [ "${mode:-}" = watch ]; then
  app=$1; attempt=$2; cls=$3; ws=$4; shift 4
  sleep 30
  if has_window; then say "window present, watchdog done"; exit 0; fi
  say "no window after 30s. clients: $(hyprctl clients -j 2>/dev/null | grep -E '"class"' | tr -d ' \t' | paste -sd, -)"
  say "monitors: $(mon_sig)"
  for p in $(tree "$app"); do
    [ -r /proc/$p/status ] || continue
    say "proc $p $(awk '/^State:/{print $2}' /proc/$p/status) wchan=$(cat /proc/$p/wchan 2>/dev/null) $(tr '\0' ' ' </proc/$p/cmdline | cut -c1-110)"
  done
  pids=$(tree "$app")
  say "SIGTERM tree: $(echo $pids)"
  kill -TERM $pids 2>/dev/null
  for n in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$app" 2>/dev/null || break; sleep 1; done
  if kill -0 "$app" 2>/dev/null; then
    pids=$(tree "$app"); say "still alive, SIGKILL tree: $(echo $pids)"
    kill -KILL $pids 2>/dev/null; sleep 1
  fi
  if [ "$attempt" -ge 4 ]; then say "giving up after $attempt attempts"; exit 1; fi
  case "$attempt" in 1) delay=15 ;; 2) delay=45 ;; *) delay=120 ;; esac
  next=$((attempt + 1))
  say "relaunch attempt $next in ${delay}s via Hyprland exec"
  sleep "$delay"
  cmd="$self --attempt $next"
  [ -n "$ws" ] && cmd="$cmd --ws \"$ws\""
  cmd="$cmd $cls $*"
  if [ -n "$ws" ]; then
    out=$(hyprctl dispatch "hl.dsp.exec_cmd('$cmd', { workspace = \"$ws\" })" 2>&1)
  else
    out=$(hyprctl dispatch "hl.dsp.exec_cmd('$cmd')" 2>&1)
  fi
  say "dispatch -> $out"
  exit 0
fi

# ---------------------------------------------------------------- launcher
cls=$1; shift
say "start: $* (ws='$ws')"
i=0
until hyprctl monitors -j 2>/dev/null | grep -q '"name"'; do
  i=$((i + 1)); [ "$i" -gt 40 ] && break
  sleep 0.5
done
say "monitor ok after $i polls"
i=0
until systemctl --user is-active --quiet xdg-desktop-portal.service \
   && busctl --user --timeout=5 call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
        org.freedesktop.portal.Settings ReadOne ss org.freedesktop.appearance color-scheme >/dev/null 2>&1; do
  i=$((i + 1)); [ "$i" -gt 60 ] && break
  sleep 1
done
say "portal ok after $i polls"
if busctl --user --timeout=10 call org.freedesktop.secrets /org/freedesktop/secrets \
     org.freedesktop.Secret.Service OpenSession sv plain s "" >/dev/null 2>&1; then
  say "secrets ok"; else say "secrets FAILED"; fi
# Monitor topology settle: unchanged for 3 consecutive seconds, 25s cap.
prev=$(mon_sig); stable=0; i=0
while [ "$stable" -lt 3 ] && [ "$i" -lt 25 ]; do
  sleep 1; i=$((i + 1)); cur=$(mon_sig)
  if [ "$cur" = "$prev" ]; then stable=$((stable + 1)); else stable=0; say "monitor topology changed at ${i}s"; fi
  prev=$cur
done
say "topology settled after ${i}s"
sleep 2

setsid -f "$self" --watch "$$" "$attempt" "$cls" "$ws" "$@" >/dev/null 2>&1 </dev/null

if [ "$attempt" = 1 ]; then
  wl=$cache/launch-retry-$cls.wl.log
  fifo=$cache/.launch-retry-$cls-$$.fifo
  rm -f "$fifo"
  if mkfifo "$fifo" 2>/dev/null; then
    ( head -c 30000000 >"$wl"; cat >/dev/null ) <"$fifo" &
    exec 2>"$fifo"
    rm -f "$fifo"
    export WAYLAND_DEBUG=client
    say "wayland debug -> $wl"
  fi
fi
say "exec"
exec "$@"
