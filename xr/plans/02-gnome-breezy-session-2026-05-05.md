# Plan: GNOME-Breezy parallel session (lewis, then verse)

_Archived 2026-05-05. Implementation landed in commits c9fbff6..(this one).
Soak (Step 7) is ongoing — see STATE.md "host status" for current state._

## Context

The 2026-05-04 sideview MVP plan died at Step 3 against an architectural
wall: `gnome-shell --nested` is nested-on-X11 (not nested-on-Wayland),
routes through XWayland under Hyprland, and Clutter init fails; v49 removed
`--nested` entirely and every replacement mode (`--display-server`,
`--headless`, `--virtual-monitor`) loses the seat-control fight to Hyprland
(`Failed to take control of the session: ... EBUSY`). See
`xr/LEARNINGS.md` "nested gnome-shell on Hyprland is impossible" and the
plan-01 postmortem.

What still works: `xr-driver` writes pose to `/dev/shm/breezy_desktop_imu`
correctly; the `breezy-gnome` derivation cleanly installs the extension to
`share/gnome-shell/extensions/breezydesktop@xronlinux.com/`; the recenter
IPC works. What's missing is a **real `gnome-shell` session** to consume
them.

The smallest path that delivers world-locked surfaces is to register a
**GNOME-on-Wayland session selectable from SDDM**. Hyprland remains
Jorge's daily-driver autologin; when he wants glasses, he logs out, picks
"GNOME on Wayland" in the SDDM greeter, and breezy-gnome auto-loads with
sensible defaults. This is the use case upstream `breezy-desktop` is
actually built for. UX cost is the logout boundary; engineering cost is
one Nix module + one dconf profile. If the soak proves the UX too
painful, the next plan revisits Hyprland-native breezy or full park
(Path 4 in the prior PLAN.md).

This plan stops at "Jorge logs into GNOME-Breezy, surfaces world-lock,
daily-drives one week."

## Implementation summary (what landed)

| Step | Commit | Notes |
|---|---|---|
| 1 — strip dead breezy-sideview wrapper | `c9fbff6` | Deleted `system/lib/xr/breezy-sideview/`, dropped Super+T binds and windowrules from `dotfiles/default/hypr/users/jorge/default/breezy.conf`. |
| 2 — add `breezy-session` module | `41aabee` | New `system/lib/xr/breezy-session/default.nix`: `desktopManager.gnome.enable = true;` + `displayManager.gdm.enable = mkForce false;` + migrated lid policy. SDDM SessionDir confirmed to surface `gnome.desktop` and `gnome-wayland.desktop`. |
| 3 — seed dconf | `acced9e` | `programs.dconf.profiles.user.databases` sets `enabled-extensions=['breezydesktop@xronlinux.com']` + four preset keys (display-distance, display-size, curved-display, widescreen-mode). All schema-verified against breezy-gnome v2.9.12. |
| 4 — recenter CLI + GNOME custom-keybinding | `bc8b2eb` | New `system/lib/xr/breezy-recenter` (writeShellApplication). Hyprland Super+R → CLI; GNOME Super+R via dconf custom-keybinding. Old shell script deleted. |
| 5 — wire into eksno (verse) | `d380d38` | Added xr/driver, xr/breezy-gnome, xr/breezy-session imports. Verse toplevel builds. |
| 6 — drop gnome48 input + doc refresh | _(this commit)_ | Removed `nixpkgs-gnome48` flake input + relocked. STATE/LEARNINGS/PLAN/FIXES updated. |

Step 7 — soak (no code) — runs in real life, not in commits.

## Stop-the-line conditions (consolidated)

Pause and rethink if any fire — mirroring plan-01's pattern:

1. **Step 2** — SDDM doesn't list a GNOME session after reboot. Don't
   paper over by importing `desktop/x11/gnome/` wholesale (re-introduces
   GDM). Find the missing nixpkgs option.
2. **Step 2** — GNOME session crash-loops back to SDDM. Bisect Catppuccin
   theming + polkit/keyring before disabling whole modules.
3. **Step 3** — A seeded dconf key isn't in v2.9.12's schema. Read the
   gschema XML in the package output; correct or drop the key. Don't
   write keys the extension won't read.
4. **Step 4** — World-lock drifts catastrophically (>30° / min) even after
   recenter. Driver-tuning territory, not this plan; file as follow-up
   and decide whether soak is still meaningful.
5. **Step 4** — World-lock doesn't engage (flat extra display).
   Re-validate IPC: `IPC_FILE_PATH` in bundled `devicedatastream.js`,
   SHM byte 0, driver heartbeat in `/dev/shm/xr_driver_state`.
6. **Step 7 soak** — Logout-to-don-glasses UX renders this unusable
   inside the first week. Park (Path 4) or re-evaluate Hyprland-native
   breezy (Path 1).

## Out of scope (explicit)

- Hyprland-native wlroots breezy. Revisit only if soak fails the UX bar.
- 3-screen / N-screen presets — upstream gschema lacks a count key
  (confirmed in plan-01).
- Auto-launch of GNOME-Breezy on glasses connect.
- Seamless hot-switch between Hyprland and GNOME-Breezy without logout —
  there is no clean way without a heavy re-architecture.
- Clipboard / process / window-state preservation across the logout
  boundary.
- Stereoscopic 3D / SBS.
- Removing the `breezy-monitor-watcher.sh` `exec-once` — keep until soak
  surfaces a reason to drop it.
