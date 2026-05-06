# Active plan

**Active phase: fix the EBUSY on monado's first atomic_commit.** Round
3 (2026-05-07) located the root cause behind the persistent black-
panel symptom: `DRM_IOCTL_MODE_ATOMIC` returns `-1 EBUSY` on monado's
first present, and Mesa's `wsi_common_display.c:3129` flattens any
non-EACCES atomic_commit failure to `VK_ERROR_SURFACE_LOST_KHR`.
Canonical writeup:
[`../memory/xr-mesa-anv-ebusy-on-first-present.md`](../memory/xr-mesa-anv-ebusy-on-first-present.md).

Phase 1 (Monado MR !2737), Phase 2 (WayVR + launcher), and Phase 3
(EDID non-desktop override + USB ACL fix) all shipped and verified
on `lewis`. **Phase 3 is architecturally complete**: monado takes
the DRM lease via `wp-drm-lease-v1`, OpenXR session reaches FOCUSED
with the real Rayneo head device, IPD = 63mm, pose data flowing.
Phase 3.5 (this phase) is the visual-output gap that remained.

## Forward options (ordered by cost)

1. **Confirm the CRTC-contention hypothesis.** Mesa's
   `wsi_display_select_crtc` picks the connector's encoder's current
   CRTC; aquamarine binds CRTC 267 to DP-2 internally even on the
   non_desktop early-return path (`SDRMConnector::connect`,
   `Monitor.cpp:246`). If monado's failing atomic targets the same
   CRTC Hyprland is holding, contention is the cause. **The existing
   strace dump cannot answer this** — strace doesn't decode the
   atomic ioctl's user-pointer prop arrays. Cheapest confirmation
   paths: kernel ftrace `drm:drm_atomic_state_*` events, an
   `LD_PRELOAD` ioctl shim that dumps `struct drm_mode_atomic`, or a
   one-line monado/Mesa instrumentation rebuild.
2. **Patch monado to retry on first-present SURFACE_LOST.**
   `comp_renderer.c renderer_present_swapchain_image` only retries on
   `OUT_OF_DATE`. Bounded retry (e.g. 3 attempts, ~16ms apart) sidesteps
   the EBUSY race regardless of the underlying root cause.
3. **Patch Mesa wsi_display: `EBUSY` → `VK_NOT_READY`.** More
   semantically correct than SURFACE_LOST. Lets monado retry via
   normal swapchain timing. Upstreamable.
4. **Hyprland-side: skip CRTC assignment for non_desktop connectors.**
   Highest leverage if (1) confirms the theory; biggest blast radius
   (touches aquamarine internals; could regress non-XR multi-monitor).

The Hyprland event-loop stall on DP-2 hot-plug
([`../memory/xr-hyprland-lease-hotplug-stall.md`](../memory/xr-hyprland-lease-hotplug-stall.md))
remains a separate open issue. The latest gen gray-screen-on-boot
(currently rolled back to gen `549bd84`) is also still open.

## Historical context

The 2026-05-06 decision document
[`plans/04-phase-3-5-decision-2026-05-06.md`](./plans/04-phase-3-5-decision-2026-05-06.md)
listed four options for Phase 3.5; the data from Round 3 effectively
chose by exposing the EBUSY. Read it only for historical framing.

The original Phase 3 implementation plan is archived at
[`plans/03-hyprland-breezy-2026-05-06.md`](./plans/03-hyprland-breezy-2026-05-06.md);
its post-reboot verification checklist all passed except the final
visual step. The "Mesa anv display-plane gap" framing was an early
misdiagnosis — see correction in
[`../memory/xr-mesa-anv-display-gap.md`](../memory/xr-mesa-anv-display-gap.md).

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
