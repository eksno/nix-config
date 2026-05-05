# Active plan

_No active plan. Start the next one with `/ultraplan` or write directly._

## Inputs for the next plan

The 2026-05-05 GNOME-Breezy session plan (archived at
[`plans/02-gnome-breezy-session-2026-05-05.md`](./plans/02-gnome-breezy-session-2026-05-05.md))
delivered SDDM-selectable GNOME-on-Wayland with breezy-gnome auto-loaded.
Currently in soak — see `STATE.md` for live state.

If the soak fails (logout UX too painful), the next plan revisits options
from the original sideview postmortem — see
[`plans/01-sideview-mvp-2026-05-04.md`](./plans/01-sideview-mvp-2026-05-04.md)
and `LEARNINGS.md`. Realistic options remain:

1. **Hyprland-native breezy.** Write a wlroots/Hyprland integration that
   reads `/dev/shm/breezy_desktop_imu` and applies head-pose transforms
   to existing surfaces. No nested compositor. Big scope (probably 2–4
   weeks), but the only path that doesn't fight upstream and avoids the
   logout boundary.
2. **Park sideview, ship glasses-as-cursor.** Revert breezy-* modules,
   set `output_mode=mouse`. Working today. No world-locked surfaces.

## Constraints any new plan must respect

- **xr-driver IPC contract is fixed.** Driver writes pose to
  `/dev/shm/breezy_desktop_imu` only when *both* `output_mode=external_only`
  and `external_mode=breezy_desktop` are set. (This is stable; we own the
  driver build.)
- **Hyprland is `lewis`'s primary compositor.** Anything that requires
  taking exclusive seat control will fight Hyprland and lose.
- **Glasses cable quality matters.** A power-only USB-C cable enumerates
  the device as HID-only with no DP alt-mode. Any plan that needs the
  glasses as a *display* must validate with the right cable first.

## Pre-existing scaffolding ready to reuse

If the new plan uses any of these, they're already written and verified:

- `xr-driver` package + module (works)
- `breezy-gnome` package (works inside a real GNOME-on-Wayland session)
- `breezy-session` module (registers GNOME via SDDM; seeds dconf)
- `breezy-recenter` CLI (works from any compositor with control of
  `/dev/shm/xr_driver_control`)
- Hyprland keybind/scripts pattern (loads correctly)
- `update-without-update.sh` for fast iteration
