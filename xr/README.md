# XR / sideview workbench

This directory tracks Jorge's effort to put world-locked virtual displays on
the **Rayneo Air 4 Pro** glasses (USB `1bbb:af50`) under Linux, primarily on
the `lewis` host (NixOS, Hyprland 0.54). It collects the active plan,
accumulated learnings, deployed-state inventory, and an archive of past
plans, so any future session — agentic or human — can pick up cold.

## How to use this directory

1. **Read [`STATE.md`](./STATE.md) first.** It captures what is currently
   deployed, what is verified working, and what is broken or deferred.
2. **Read [`LEARNINGS.md`](./LEARNINGS.md) before debugging.** Most
   surprising failures we've already hit (and documented).
3. **Open [`PLAN.md`](./PLAN.md)** to see the active plan, or to write the
   next one.
4. **Browse [`plans/`](./plans/)** for archived plans (date-stamped, with
   postmortems where relevant).

## What lives where (outside this directory)

| Concern | Path |
|---|---|
| xr-driver Nix package + module | `system/lib/xr/driver/` |
| breezy-gnome extension package | `system/lib/xr/breezy-gnome/` |
| breezy-sideview wrapper package | `system/lib/xr/breezy-sideview/` |
| xr-driver runtime config (template) | `dotfiles/default/xr_driver/config.ini` |
| Hyprland keybinds + windowrules | `dotfiles/default/hypr/users/jorge/default/breezy.conf` |
| Hyprland helper scripts | `dotfiles/default/hypr/shared/scripts/breezy-*.sh` |
| Bug log (system-wide) | `FIXES.md` |
| User imports xr modules | `system/users/jorge/dev/default.nix` |

## When to edit which file

- **Hit a new failure mode** → append to `LEARNINGS.md` under the matching
  topic (or create a new topic). Be terse but include the *why*.
- **Deploy something new** or **change the contract of something deployed** →
  update `STATE.md`.
- **Pick up a new direction** (new plan, replan after a wall) → archive the
  current `PLAN.md` to `plans/NN-<title>-<date>.md`, then write the new one
  in `PLAN.md`.

The repo's top-level `FIXES.md` remains the canonical bug-log for *the
whole NixOS config*. Use it for fixes that aren't XR-specific (or that may
matter to non-XR future-Jorge). XR-specific learnings live here.
