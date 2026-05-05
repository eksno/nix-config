# Active plan

**[`plans/03-hyprland-breezy-2026-05-06.md`](./plans/03-hyprland-breezy-2026-05-06.md)** — Open-source Hyprland breezy via Monado + WayVR.

Phase 1 (Monado patched with MR !2737) and Phase 2 (WayVR + launcher)
shipped. **Phase 3 — DRM direct lease — is the current blocker, now
replanned around an EDID override.** The original `hyprctl keyword
monitor disable` approach was tested 2026-05-06 and proven wrong:
wlroots only advertises connectors with the EDID `non_desktop` bit
set on the lease device, and Hyprland inherits that. Disabling the
monitor doesn't make it leasable — it strictly breaks monado worse
than leaving it alone. The new path is a kernel-cmdline EDID
override (`drm.edid_firmware=DP-2:edid/glasses.bin`) with the
non-desktop bit flipped. See the plan file for the implementation
sketch.

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
- **Hyprland is `lewis`'s primary compositor.** wlroots only advertises
  outputs with the EDID `non_desktop` bit set on `wp-drm-lease-v1`.
  Toggling the monitor in Hyprland (`disable`/`preferred`) does NOT
  make the connector leasable. See LEARNINGS.md "wlroots only
  advertises non-desktop outputs via wp-drm-lease-v1" for why and
  what works instead (EDID override).
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
