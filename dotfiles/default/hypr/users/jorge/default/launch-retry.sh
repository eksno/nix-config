#!/bin/sh
# launch-retry.sh [--attempt N] [--ws "RULE"] <window-class> <cmd...>
#
# Startup launcher for the Chromium apps (Chrome, Discord).
#
# Root cause of the windowless logins (FIXES.md 2026-10-24): glasses-mirror-
# watcher.sh turns eDP-1 into a mirror of the VG258 a few seconds after
# Hyprland starts. Hyprland destroys eDP-1's workspaces but keeps it as the
# "last monitor" until the next input event, so every window created after
# that is refused with "mapWindow: no valid monitor/workspace, aborting map"
# (hyprland.log). The apps run fine, they just never get mapped, until the
# user moves the mouse or presses Super+N, which re-points the last monitor.
#
# So this script:
#   1. gates on: a monitor present, xdg-desktop-portal + secret service
#      answering, monitor topology unchanged for 3s,
#   2. re-focuses the first ACTIVE (non-mirror) monitor so Hyprland has a valid
#      last monitor / workspace to map onto,
#   3. execs the app (keeps the pid Hyprland bound the workspace rule to),
#   4. a detached watchdog checks for a window of <class> after 30s; if none,
#      logs diagnostics to ~/.cache/launch-retry.log, kills the app's process
#      tree, re-focuses a valid monitor and asks Hyprland to run this script
#      again with --attempt N+1 (same workspace rule); 15s/45s/120s apart,
#      four attempts max.
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
log=/home/jorge/.cache/launch-retry.log
say() { printf '%s %s#%s[%s]: %s\n' "$(date +%T)" "$cls" "$attempt" "$$" "$*" >>"$log"; }
has_window() { hyprctl clients -j 2>/dev/null | grep -qE "\"class\": *\"$cls\""; }
mon_sig() { hyprctl monitors all -j 2>/dev/null | grep -E '"(description|mirrorOf|x|y|disabled|dpmsStatus)"' | tr -d ' \t\n'; }
tree() { echo "$1"; for c in $(ps -o pid= --ppid "$1" 2>/dev/null); do tree "$c"; done; }
# Point Hyprland's "last monitor" at a real, active output. `hyprctl monitors`
# (without `all`) lists only active, non-mirror monitors.
refocus() {
  m=$(hyprctl monitors -j 2>/dev/null | grep -m1 -E '^\s*"name": *"' | sed -E 's/.*"name": *"([^"]*)".*/\1/')
  [ -n "$m" ] || { say "refocus: no active monitor found"; return 1; }
  out=$(hyprctl dispatch "hl.dsp.focus({ monitor = '$m' })" 2>&1)
  say "refocus monitor $m -> $out"
}

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
  refocus
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
refocus
sleep 1

setsid -f "$self" --watch "$$" "$attempt" "$cls" "$ws" "$@" >/dev/null 2>&1 </dev/null
say "exec"
exec "$@"
