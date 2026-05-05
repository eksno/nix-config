# Hyprland-breezy via Monado + WayVR (open-source replacement)

Started: 2026-05-05
Status: Phase 1 + Phase 2 plumbing shipped; Phase 3 (DRM direct lease) is the
        current blocker between "OpenXR session reaches FOCUSED" and "user
        sees correct VR rendering on the glasses."

## Why this plan

The 2026-05-05 GNOME-Breezy session plan (archived at
[`02-gnome-breezy-session-2026-05-05.md`](./02-gnome-breezy-session-2026-05-05.md))
delivered the full pipeline up to the breezy-desktop GNOME extension —
then hit the upstream `is_productivity_granted()` SHM gate. World-lock
requires a paid tier from upstream, and Jorge's two constraints are:

> "no GNOME .. and no paying."

This plan is the open-source path: Monado as the OpenXR runtime
(rebuilt with the Rayneo MR !2737 driver), WayVR as the OpenXR client
that draws head-locked panels in 3D space, all natively on Hyprland.
No upstream paywall touched, no GNOME session needed.

## Phase 1 — Monado patched with MR !2737 (DONE)

**Commit:** `5f8fc74` — "feat(xr): package monado with MR !2737 rayneo driver"

- `system/lib/xr/monado-rayneo/{package.nix,default.nix}` — overrides
  stock nixpkgs `monado` with the head SHA of MR !2737 from
  gitlab.freedesktop.org/monado/monado, filtering nixpkgs'
  `monado-cylinder-aspectRatio.patch` (already in MR source, would
  apply-reversed).
- Wired into both `jorge` and `eksno` dev imports.
- Verified: `monado-cli probe` enumerates the Rayneo Air 4 Pro as a
  head device with view count 2 (stereo). Stock Monado does NOT —
  its `xreal_air` builder only matches XREAL VID 0x3318.

## Phase 2 — WayVR + launcher (DONE through OpenXR FOCUSED)

**Commit:** `2bef060` — "feat(xr): add breezy-hyprland launcher (Monado + WayVR)"

- `system/lib/xr/breezy-hyprland/{default.nix,launcher.nix}`.
- Adds `pkgs.wayvr` (26.2.1, in nixpkgs as the renamed WlxOverlay-S).
- `XR_RUNTIME_JSON` set both system-wide AND in the launcher itself
  (system var only takes effect on next login).
- `breezy-hyprland` launcher orchestrates the full lifecycle:
  stop xr-driver → clean stale monado.pid → start monado-service
  in background → wait for OpenXR socket → exec wayvr in foreground →
  trap-driven cleanup on exit (kill monado, reap sleep, restart xr-driver).
- Three subtle constraints discovered (full detail in `LEARNINGS.md`):
  - monado-service stdin must be a pollable fd (not TTY, not /dev/null)
  - the pipe must stay open (sleep infinity, not `true |`)
  - XR_RUNTIME_JSON must be set in the launcher's own process

**Verified end-to-end:** WayVR connects to Monado via OpenXR, finds
the Rayneo Air 4 Pro as the head device, OpenXR session walks
IDLE → READY → SYNCHRONIZED → VISIBLE → FOCUSED, IPD = 63mm
(pose data flowing), GPU screen capture initialized, UI text atlas
drawn.

**What's NOT yet correct:** the actual rendered output. Monado falls
back to Wayland-windowed mode because Hyprland holds the glasses DRM
connector. The 3840x1080 SBS-packed Wayland surface lands somewhere
on Jorge's compositor (not on the glasses output as direct rendering),
so the glasses end up showing the SBS pack's left half stretched +
undefined buffer (rainbow vertical lines) on the other eye. This is
why Jorge sees "half working, half rainbow bars" with a
"Monado - openxr not responding" Hyprland watchdog popup.

## Phase 3 — DRM direct lease (BLOCKING, next session resumes here)

The architecturally-correct fix: release the glasses DRM connector
from Hyprland before launching monado-service, so monado can take a
direct DRM lease and render straight to the connector with no
Wayland mirror window in the loop.

### Concrete plan for the launcher

Add two `hyprctl keyword monitor` calls to `breezy-hyprland`:

1. **Before starting monado:**
   ```
   hyprctl keyword monitor "desc:SmartGlasses,disable"
   ```
   Drops the output from wlroots, freeing the DRM connector.

2. **In the EXIT trap (after monado is killed):**
   ```
   hyprctl keyword monitor "desc:SmartGlasses,preferred,auto,1"
   ```
   Re-enables the output so the user gets their glasses back as a
   normal Hyprland monitor when Monado quits.

The exact `desc:` string needs to be confirmed from
`hyprctl monitors all` while glasses are plugged in — the value is
some prefix of "Technical Concepts Ltd SmartGlasses" or similar.

### Open questions for next session

- **Does Monado's MR !2737 actually take the lease successfully?** The
  earlier monado log already showed `Available DRM lease device:
  /dev/dri/card1` — so the lease infrastructure works, the only
  blocker was no available connectors. Once Hyprland releases, this
  should "just work" — but verify.
- **Does WayVR render both eyes correctly in direct mode?** It should;
  Monado handles the stereo SBS packing internally and the glasses
  receive a proper SBS signal on the connector. But empirical
  verification needed.
- **What does "Handsfree mode" actually look like?** WayVR's default UI
  expects 6DoF + controllers. Need to enable Handsfree via the
  dashboard so head-pointer cursor works for our 3DoF setup.
- **How does the user dismiss/configure WayVR panels with no
  keyboard/mouse?** The "Show" hotkey on the desktop side is one path;
  WayVR also has a virtual keyboard overlay.

## Phase 4 — Polish (after Phase 3 lands)

In rough priority:

- **N-screen curved-arc layout** — port the geometry math from
  breezy-gnome's `virtualdisplaysactor.js` so multiple Hyprland
  outputs (or per-workspace captures) render as curved panels in
  3D space.
- **Per-workspace capture sources** — instead of capturing existing
  outputs, use Hyprland headless outputs (`hyprctl output create
  headless`) so each WayVR panel can show a different workspace.
- **Recenter integration** — Monado has its own recenter mechanism;
  bind Super+R (already bound to `breezy-recenter` for the
  GNOME-Breezy session) to it.
- **Smoothing tuning** — match breezy-gnome's smooth-follow behavior
  if WayVR's defaults feel jittery.

## Phase 5 — Future (out of scope this plan, captured for memory)

- **Webcam-based 6DoF** — Jorge has expressed interest. Would let us
  do positional tracking, not just head orientation. Likely path:
  Monado's `north_star` builder or a separate SLAM driver.
- **Sombrero shader port** — the per-glasses-model lens distortion
  shader from breezy-gnome. Monado handles its own lens correction
  via the Rayneo driver's view configuration; only port if upstream
  Monado's correction is noticeably worse.

## Reference points (don't lose these)

- Monado MR !2737: https://gitlab.freedesktop.org/monado/monado/-/merge_requests/2737
- WayVR upstream: https://github.com/wayvr-org/wayvr (was
  `galister/wlx-overlay-s`, now consolidated)
- WayVR Handsfree config issue: github.com/wayvr-org/wayvr/issues/437
  (closed; head-pointer mode confirmed)
