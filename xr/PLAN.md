# Active plan

**[`plans/04-phase-3-5-decision-2026-05-06.md`](./plans/04-phase-3-5-decision-2026-05-06.md)** — Decision document (not an implementation plan). Awaiting Jorge's choice between four forward options.

Phase 1 (Monado MR !2737), Phase 2 (WayVR + launcher), and Phase 3
(EDID non-desktop override + USB ACL fix) all shipped and verified
on `lewis`. **Phase 3 is architecturally complete**: monado takes
the DRM lease via `wp-drm-lease-v1`, OpenXR session reaches FOCUSED
with the real Rayneo head device, IPD = 63mm, pose data flowing.

**Visual output is still black.** The original "Mesa anv display-plane
gap" framing was wrong (see correction in
[`../memory/xr-mesa-anv-display-gap.md`](../memory/xr-mesa-anv-display-gap.md)).
First diagnosed root cause was monado swapchain usage flags
(STORAGE-only on the compute path), patched in `3bf13da` and verified
on the monado side. **Round 2 (2026-05-06 evening):** SURFACE_LOST has
reappeared in a different form — first present fails despite the
swapchain creating cleanly with the right usage flags and 3840x1080
extent. Active phase is now diagnosing the new SURFACE_LOST plus the
Hyprland event-loop stall on DP-2 hot-plug (see
[`../memory/xr-hyprland-lease-hotplug-stall.md`](../memory/xr-hyprland-lease-hotplug-stall.md)),
not the original "no display plane" claim.

The original Phase 3 plan is archived at
[`plans/03-hyprland-breezy-2026-05-06.md`](./plans/03-hyprland-breezy-2026-05-06.md);
its post-reboot verification checklist all passed except the final
visual step.

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
