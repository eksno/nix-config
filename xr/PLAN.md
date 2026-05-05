# Active plan

_No active plan. Start the next one with `/ultraplan` or write directly._

## Inputs for the next plan

The 2026-05-04 sideview MVP plan (archived at
[`plans/01-sideview-mvp-2026-05-04.md`](./plans/01-sideview-mvp-2026-05-04.md))
hit an architectural wall — see that file's postmortem section, and
`LEARNINGS.md` "nested gnome-shell on Hyprland is impossible".

When picking a new direction, the realistic options are:

1. **Hyprland-native breezy.** Write a wlroots/Hyprland integration that
   reads `/dev/shm/breezy_desktop_imu` and applies head-pose transforms to
   existing surfaces. No nested compositor. Big scope (probably 2–4 weeks),
   but the only path that doesn't fight upstream.
2. **TTY-swap GNOME session.** Configure a separate display-manager target
   that boots an actual GNOME session on TTY2. Switch via `chvt 2` when
   wearing glasses. Heavy daily UX cost, but it's how upstream
   breezy-desktop is intended to be used. Lowest engineering cost.
3. **gamescope or sway as the breezy host.** Either uses wlroots and might
   support nested mutter or host the breezy extension differently than
   Hyprland. Could replace Hyprland for the breezy session specifically
   (i.e. boot Hyprland normally, swap to a sway+breezy session via TTY or
   process replacement when needed).
4. **Park sideview, ship glasses-as-cursor.** Revert the breezy-* modules,
   set `output_mode=mouse`, and call Step 1 + xr-driver the whole feature.
   Working today on lewis. No world-locked surfaces.

## Constraints any new plan must respect

- **xr-driver IPC contract is fixed.** Driver writes pose to
  `/dev/shm/breezy_desktop_imu` only when *both* `output_mode=external_only`
  and `external_mode=breezy_desktop` are set. (This is stable; we own the
  driver build.)
- **Cross-version GNOME pinning has hidden costs.** The `nixpkgs-gnome48`
  flake input we added still works as an input but mixing 48-mutter's
  graphics stack with unstable runtime drivers caused Clutter init failures
  in this session. If a future plan keeps the pin, expect to also pin or
  override the GL/EGL stack.
- **Hyprland is `lewis`'s primary compositor.** Anything that requires
  taking exclusive seat control will fight Hyprland and lose.
- **Glasses cable quality matters.** A power-only USB-C cable enumerates
  the device as HID-only with no DP alt-mode. Any plan that needs the
  glasses as a *display* must validate with the right cable first.

## Pre-existing scaffolding ready to reuse

If the new plan uses any of these, they're already written and verified:

- `xr-driver` package + module (works)
- `breezy-gnome` package (builds; consumer needed)
- Hyprland keybind/scripts pattern (loads correctly)
- `update-without-update.sh` for fast iteration
- `breezy-recenter.sh` for Super+R recentering
