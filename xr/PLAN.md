# Active plan

**HARD-BLOCKED 2026-05-08: DP altmode firmware-wedged on lewis.** No
"glasses panel" work can progress until lewis's EC firmware recovers
from its current "refuse to register CAMs for any partner" state. UCSI
debugfs queries fingerprint the failure: partner advertises DP altmode
SVID `0xff01` correctly, EC has the data, but `GET_CAM_SUPPORTED`
returns 0 and `SET_NEW_CAM` times out. Cable is fine (works on phone).
Cold cycle didn't recover. See STATE.md "2026-05-08 morning session"
section and `memory/xr-lewis-ec-refuses-altmode.md` for the full
diagnostic and recovery options.

**While altmode is broken, what's still possible**: sideview / mouse
mode through xr-driver works (USB+HID, no altmode needed); software
changes that don't need real glasses display verification (Phase 4
design, monado-retry-patch code review, Mesa workstream code review);
re-testing periodically with the 5-command UCSI recipe to detect when
the EC recovers.

**Pre-block plan (resume when altmode is back):** figure out why the
glasses panel is DARK (not black) and verify the monado SURFACE_LOST
retry patch on real hardware. The 2026-05-07 evening session moved
Phase 3.5 forward materially:

- Workstream 1 (CRTC diagnostic) — **DONE.** Confirmed monado IS
  targeting CRTC 267 (the same CRTC aquamarine binds to DP-2). Round 3
  EBUSY is **intermittent**, not always-reproducing — the same shim
  run captured 4466 successive atomic_commit successes and 47670
  frames presented at ~30 fps.
- Workstream 2 (monado SURFACE_LOST retry) — **AUTHORED + COMMITTED**
  (`baa7b4e` + `d4865e4` + `6265f3c`), not yet built or tested on
  hardware.
- Workstream 3 (Mesa EBUSY → VK_NOT_READY) — **DEFERRED.** Low priority
  now that EBUSY is intermittent and monado retries.

The user-visible symptom shifted: the panel went from **completely
black** (no signal / DPMS off) to **dark-but-on** (scanout happening,
content dim). That's a different problem, possibly with three
explanations (see STATE.md "Operational findings"). Canonical writeup:
[`../memory/xr-mesa-anv-ebusy-on-first-present.md`](../memory/xr-mesa-anv-ebusy-on-first-present.md).

Phase 1 (Monado MR !2737), Phase 2 (WayVR + launcher), and Phase 3
(EDID non-desktop override + USB ACL fix) all shipped and verified
on `lewis`. **Phase 3 is architecturally complete**: monado takes
the DRM lease via `wp-drm-lease-v1`, OpenXR session reaches FOCUSED
with the real Rayneo head device, IPD = 63mm, pose data flowing.

## Next steps (ordered)

0. **Recover DP altmode on lewis** (NEW, blocks everything else).
   The EC firmware refuses to register CAMs for the Rayneo partner;
   no DP signal reaches the glasses panel. Recovery options ordered
   by cost (Jorge to choose; he is not familiar with BIOS work and
   wants to be careful):
   - (a) **Wait + retest periodically**: re-run the 5-command UCSI
     recipe in `memory/xr-lewis-ec-refuses-altmode.md` every few
     hours. If `GET_CAM_SUPPORTED` returns nonzero, altmode is
     back; resume Phase 3.10. Zero risk, possibly zero progress.
   - (b) **BIOS "Restore Defaults"** (NOT a flash): F2 at POST →
     F9 → confirm → F10 → confirm. Resets BIOS settings to factory,
     usually clears EC NVRAM as a side effect. Safe; doesn't modify
     firmware code; doesn't touch OS or files. Worst case: WiFi or
     fan profiles re-enable to defaults.
   - (c) Try a **TBT4-certified USB-C cable** if one becomes
     available (rules out cable-specific firmware quirk).
   - (d) BIOS update from ASUS (last-resort; flashing risk).

1. **Visual verification (read-only, blocks on Jorge).** Jorge to
   report exactly what the dark screen looks like: uniform dark,
   gradient, motion-tracked content moving with head pose, OSD text,
   etc. The answer routes the next workstream:
   - uniform → likely brightness or 10-bit-into-8-bit format issue
   - tracked content visible → cosmetic only; investigate brightness
   - completely featureless → SwitchTo3D may not have actually fired,
     or composition layer is empty

2. **Confirm `SwitchTo3D` actually fired.** Now that `XRT_LOG=debug`
   is wired into the v2 runner, grep this run's
   `/run/user/1000/monado-service.log` (starting from the **second**
   occurrence of `The Monado service has started`) for:
   - `Switching to 3D mode...` (DEBUG; should appear if init reached
     that path)
   - `3D mode confirmed, waiting for settle...` (DEBUG; success)
   - `Failed to send 3D mode request` / `3D mode switch timeout`
     (WARN; failure paths — visible even at INFO)
   See `../memory/xr-monado-debug-log-level.md` for the macro details.

3. **Build #19 (monado retry patch) and re-verify on real hardware.**
   `./update-without-update.sh && hyprctl reload`, then re-run the v2
   runner. Check that:
   - if EBUSY fires, the new retry log lines (added in `baa7b4e` /
     `d4865e4` / `6265f3c`) appear and the present cycle continues
   - no regression on the happy path (commits ran clean before)

4. **Future / conditional:** brightness control investigation if (1)
   shows tracked-but-dim content. Mesa workstream (#20) only if EBUSY
   proves frequent in real workloads — `intermittent` is not the same
   as `rare`, so collect more data points first.

The Hyprland event-loop stall on DP-2 hot-plug
([`../memory/xr-hyprland-lease-hotplug-stall.md`](../memory/xr-hyprland-lease-hotplug-stall.md))
remains a separate open issue. The latest gen gray-screen-on-boot
(currently rolled back to gen `549bd84`) is also still open.

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
