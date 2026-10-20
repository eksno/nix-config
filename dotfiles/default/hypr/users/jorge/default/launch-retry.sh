#!/bin/sh
# launch-retry.sh <window-class> <cmd...>
#
# Startup launcher for Chromium apps (Chrome, Discord). After every
# crash + re-login since 2026-10-15 they came up running but windowless;
# a graceful SIGTERM + relaunch always brought the window back. So:
#   1. wait until Hyprland has a monitor and the portal + secret service
#      answer (they start in the same second as the apps on login),
#   2. exec the app (keeps the pid Hyprland attached the workspace rule to),
#   3. if no window of <class> exists after 30s, SIGTERM and relaunch once.
cls=$1; shift

i=0
until hyprctl monitors -j 2>/dev/null | grep -q '"name"'; do
  i=$((i + 1)); [ "$i" -gt 40 ] && break
  sleep 0.5
done
busctl --user --timeout=10 call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
  org.freedesktop.portal.Settings ReadOne ss org.freedesktop.appearance color-scheme >/dev/null 2>&1
busctl --user --timeout=10 call org.freedesktop.secrets /org/freedesktop/secrets \
  org.freedesktop.Secret.Service OpenSession sv plain s "" >/dev/null 2>&1
sleep 1

(
  sleep 30
  hyprctl clients -j 2>/dev/null | grep -qE "\"class\": *\"$cls\"" && exit 0
  # $$ is this shell's pid, which exec below turns into the app itself.
  kill -TERM "$$" 2>/dev/null
  for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    kill -0 "$$" 2>/dev/null || break
    sleep 1
  done
  exec uwsm app -- "$@"
) >/dev/null 2>&1 &

exec "$@"
