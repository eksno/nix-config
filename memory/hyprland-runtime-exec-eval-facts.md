---
type: project
title: Hyprland 0.56 Lua-config runtime facts (exec, eval, cgroups)
created: 2026-10-23
---

Verified live on lewis (Hyprland 0.56.2, Lua config, uwsm session) while debugging the
windowless Chrome/Discord startup (FIXES.md 2026-10-20 + 10-23 note).

- `hyprctl eval "hl.monitor({...})"` returns `ok` but changes NOTHING at runtime: `hyprctl monitors all -j`
  `mirrorOf`/`x` were identical before and after both a mirror rule and a standalone rule, and socket2
  emitted no `monitoradded/monitorremoved`. Eval'd monitor rules only take effect on Hyprland's next
  output pass (hotplug, startup). `glasses-mirror-watcher.sh` works only because it fires during those
  passes. Do not use eval to "reproduce" a topology change; it will look like a negative result.
- `hyprctl dispatch exec <cmd>` fails under the Lua config (`')' expected`). Working runtime launch
  that keeps workspace rules: `hyprctl dispatch "hl.dsp.exec_cmd('cmd', { workspace = \"5 silent\" })"`.
  From a shell without Hyprland's rule, `setsid -f uwsm app -- <cmd> </dev/null` (bare `uwsm app` blocks).
- Hyprland's exec children (`hl.exec_cmd`) live in the compositor's own cgroup,
  `wayland-wm@hyprland.desktop.service`, NOT in per-app `app-*.scope` units. Stopping that unit kills
  Hyprland. Kill a stuck exec'd app by process tree (`ps --ppid` recursion), never by unit. The
  `app-Hyprland-<cmd>-<hash>.scope` units seen in `systemctl --user` come from `uwsm app`, not Hyprland.
- `debug:disable_logs = true` (default here) means `hyprland.log` records nothing after startup: no
  window map/surface events. `users/jorge/default/debug.lua` turns it on while the startup bug is open.
  Flipping it with `hyprctl eval "hl.config({debug={disable_logs=false}})"` changed the option value but
  produced no new log lines in the running instance.
- Chrome overwrites `/proc/<pid>/environ` (unusable); `strace -p` on Chrome is refused
  (`yama.ptrace_scope=1`). Compare env via another process exec'd by the same Hyprland (e.g. kitty).
