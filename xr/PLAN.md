# Active plan

**[`plans/03-hyprland-breezy-2026-05-06.md`](./plans/03-hyprland-breezy-2026-05-06.md)** — Open-source Hyprland breezy via Monado + WayVR.

Phase 1 (Monado patched with MR !2737) and Phase 2 (WayVR + launcher)
shipped. **Phase 3 — DRM direct lease via Hyprland monitor toggle —
is the current blocker.** OpenXR session already reaches FOCUSED end
to end; the visual rendering on the glasses is wrong because Monado
is in Wayland-windowed mode (Hyprland holds the DRM connector). See
the plan file for resumption details.

## Why this is the active path

The 2026-05-05 GNOME-Breezy plan (archived as
[`plans/02-gnome-breezy-session-2026-05-05.md`](./plans/02-gnome-breezy-session-2026-05-05.md))
hit the upstream `is_productivity_granted()` paywall. Jorge's
constraints — "no GNOME, no paying" — make this Monado+WayVR path
the only viable open-source replacement. The breezy-gnome stack stays
deployed (working as a build artifact) and the GNOME session stays
SDDM-selectable as a fallback if anyone ever buys a productivity tier.

## Constraints any work in this area must respect

- **xr-driver IPC contract is fixed.** Driver writes pose to
  `/dev/shm/breezy_desktop_imu` only when *both* `output_mode=external_only`
  and `external_mode=breezy_desktop` are set, AND a productivity tier
  is granted (the latter is upstream-paywalled — can't bypass without
  forking the driver).
- **Hyprland is `lewis`'s primary compositor.** Anything that needs
  exclusive seat or DRM connector control must coordinate with Hyprland
  (release the connector before, restore after). See LEARNINGS.md for
  the `hyprctl keyword monitor desc:SmartGlasses,disable` pattern.
- **Glasses cable quality matters.** A power-only USB-C cable
  enumerates the device as HID-only with no DP alt-mode. Any plan that
  needs the glasses as a *display* must validate with the right cable
  first.
- **Don't SIGKILL display-grabbing processes mid-frame.** Use SIGINT
  and let the trap clean up — abrupt teardown leaves DRM half-released
  and trashes Hyprland's monitor list. (Saved as a feedback memory.)

## Pre-existing scaffolding ready to reuse

If a future plan uses any of these, they're already written and
verified:

- `xr-driver` package + module (works; mouse mode usable, breezy-mode
  needs license)
- `breezy-gnome` package (works inside a real GNOME-on-Wayland
  session; gated by license at runtime)
- `breezy-session` module (registers GNOME via SDDM; seeds dconf)
- `breezy-recenter` CLI (works from any compositor with control of
  `/dev/shm/xr_driver_control`)
- **`monado-rayneo` package** (Monado + MR !2737; enumerates Rayneo)
- **`breezy-hyprland` launcher** (orchestrates monado-service + wayvr;
  reaches OpenXR FOCUSED; Phase 3 will add Hyprland monitor toggle)
- Hyprland keybind/scripts pattern (loads correctly)
- `update-without-update.sh` for fast iteration without flake bumps
