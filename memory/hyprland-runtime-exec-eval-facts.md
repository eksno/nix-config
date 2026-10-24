---
type: project
title: Hyprland 0.56 Lua-config runtime facts (exec, eval, cgroups, stale last monitor)
created: 2026-10-23
updated: 2026-10-24
---

Verified live on lewis (Hyprland 0.56.2, Lua config, uwsm session) while debugging the
windowless Chrome/Discord startup (FIXES.md 2026-10-20, 10-24).

- **Stale "last monitor" after an output becomes a mirror.** When `glasses-mirror-watcher.sh` flips
  eDP-1 into a mirror of the VG258, Hyprland destroys eDP-1's workspaces but keeps eDP-1 as the last
  focused monitor until the next input event. Every window created in between is refused:
  `ERR ]: mapWindow: no valid monitor/workspace, aborting map for <window>` in `hyprland.log`. The app
  runs normally (surfaces, dmabuf, commit all happen); it just never maps. Any mouse move / Super+N
  fixes it for later windows. Workaround: `hyprctl dispatch "hl.dsp.focus({ monitor = '<name>' })"` on
  the first entry of `hyprctl monitors -j` (active, non-mirror monitors only). Monitor by numeric id
  (`monitor = 1`) is "monitor not found"; use the name.
- `hyprctl eval "hl.monitor({...})"` returns `ok` but changes NOTHING at runtime: `hyprctl monitors all -j`
  `mirrorOf`/`x` were identical before and after both a mirror rule and a standalone rule, and socket2
  emitted no `monitoradded/monitorremoved`. Eval'd monitor rules only take effect on Hyprland's next
  output pass (hotplug, startup). The watcher works only because it fires during those passes.
- `hyprctl dispatch exec <cmd>` fails under the Lua config (`')' expected`). Working runtime launch
  that keeps workspace rules: `hyprctl dispatch "hl.dsp.exec_cmd('cmd', { workspace = \"5 silent\" })"`.
  From a shell without Hyprland's rule, `setsid -f uwsm app -- <cmd> </dev/null` (bare `uwsm app` blocks).
- Hyprland's exec children (`hl.exec_cmd`) live in the compositor's own cgroup,
  `wayland-wm@hyprland.desktop.service`, NOT in per-app `app-*.scope` units. Stopping that unit kills
  Hyprland. Kill a stuck exec'd app by process tree (`ps --ppid` recursion), never by unit. The
  `app-Hyprland-<cmd>-<hash>.scope` units seen in `systemctl --user` come from `uwsm app`, not Hyprland.
- `debug:disable_logs = true` (default here) leaves `hyprland.log` with nothing after startup. With
  `users/jorge/default/debug.lua` (`disable_logs = false`) the log shows `[executor] Executing ...`,
  `New wl_surface`, `Window X set class to Y`, `Rule workspace matched`, and the `mapWindow` errors.
  This is what found the root cause; keep it on. Flipping it via `hyprctl eval` at runtime does not
  start logging in the running instance.
- Chrome overwrites `/proc/<pid>/environ` (unusable); `strace -p` on Chrome is refused
  (`yama.ptrace_scope=1`). Compare env via another process exec'd by the same Hyprland (e.g. kitty).
  Side effect: Hyprland reads `HL_INITIAL_WORKSPACE_TOKEN` from the client's environ, so Chrome's
  exec workspace rule is only sometimes applied.
- `hyprctl` from a long-lived shell after a re-login talks to the DEAD instance (stale
  `HYPRLAND_INSTANCE_SIGNATURE`); pick the newest dir in `/run/user/1000/hypr/` first.
