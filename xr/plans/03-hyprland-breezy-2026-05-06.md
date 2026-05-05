# Hyprland-breezy via Monado + WayVR (open-source replacement)

Started: 2026-05-05
Status: Phase 1 + Phase 2 plumbing shipped. Phase 3 (DRM direct lease)
        replanned 2026-05-06: original `hyprctl keyword monitor disable`
        approach proven wrong (wlroots only leases non-desktop outputs);
        new path is EDID override to force the non-desktop bit. Launcher
        reverted to Phase 2 baseline (Wayland-windowed, FOCUSED but
        renders wrong) until EDID work lands.

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

## Phase 3 — DRM direct lease (BLOCKING, replanned 2026-05-06)

### What we tried first (and why it doesn't work)

The original plan was: `hyprctl keyword monitor "desc:..., disable"`
before monado, restore in the cleanup trap. **Tested 2026-05-06 —
this is strictly worse than doing nothing.**

What actually happens:

- `desc:Technical Concepts Ltd SmartGlasses` is the right desc string.
- `, disable` does drop the monitor (`disabled: true` in
  `hyprctl monitors all`), and the cleanup trap restoring with
  `, 1920x1080@120, auto, 1, mirror, HDMI-A-1` (matching the user's
  baseline at `dotfiles/.../jorge/default/monitor.conf:10`) works
  cleanly — monitor list comes back exactly as before.
- BUT monado still logs `Found no connectors available for direct
  mode`. Then it tries Wayland-windowed mode, fails to bind a
  surface (no SmartGlasses output to bind to anymore), and exits
  cleanly with `Server exiting: '0'` ~2s after Vulkan init.
- WayVR then can't connect to the dead socket and bails.

Root cause (see LEARNINGS.md "wlroots only advertises non-desktop
outputs via wp-drm-lease-v1"): wlroots only exposes connectors with
the EDID/DRM `non_desktop` property set on the lease device. Rayneo
glasses identify as a normal monitor, so they're never advertised
no matter how we manipulate them in Hyprland.

The launcher reverted the disable — Phase 2 state (Wayland-windowed,
reaches FOCUSED but renders wrong) is preserved as the working baseline.

### Real Phase 3: EDID override to force non-desktop

The clean architectural fix is to make the glasses look like a
non-desktop output to wlroots from boot. Linux supports loading
override EDIDs via the firmware loader.

**Sketch (not yet implemented):**

1. **Capture the current EDID:**
   ```
   cat /sys/class/drm/card1-DP-2/edid > /tmp/glasses-orig.bin
   ```
   (or whatever connector path has the SmartGlasses EDID at next
   plug-in; the connector is known to be DP-2 on lewis.)

2. **Flip the non-desktop bit.** This lives in the DisplayID
   extension block (DisplayID block tag 0x0A "Display Parameters" has
   a feature support bit, or the more recent DisplayID Type II header
   has a "non-desktop" flag). Easiest approach: write a small
   Python/Rust utility that parses the EDID, adds/modifies the
   DisplayID extension to set the non-desktop bit, recomputes the
   checksum, writes the result.

3. **Install as firmware.** NixOS has `hardware.firmware =
   [ <derivation-with-edid> ]` or a simpler `boot.kernelParams =
   [ "drm.edid_firmware=DP-2:edid/glasses.bin" ]`, with the file
   placed at `/lib/firmware/edid/glasses.bin` via a derivation.

4. **Verify.** After reboot:
   ```
   cat /sys/class/drm/card1-DP-2/non_desktop  # should print 1
   ```
   and `hyprctl monitors all` should NOT list DP-2 in the active
   compositor outputs (Hyprland skips non-desktop). Monado's lease
   device should then advertise it; `monado-cli probe` and the full
   pipeline should work without the disable workaround.

**Tradeoff:** while the override is in place, the glasses will not
appear as a normal Hyprland monitor — they're VR-only. For Jorge's
XR-first workflow, this is acceptable; the rare "use as regular
external monitor" case can revert by removing the kernel param and
rebooting.

### Alternate paths (only if EDID override blocked)

- **Patch wlroots/Hyprland** to also lease manually-disabled
  outputs. Closer to a "VR mode toggle" UX, but invasive and
  upstream-rejected without strong rationale.
- **Tune Wayland-windowed mode** so the SBS-packed surface lands
  correctly on the glasses output. Requires putting the glasses in
  their custom 3840x1080 SBS mode via HID (rayneo driver already
  knows how) and Hyprland fullscreening monado's window on that
  output. Complex; the EDID path is simpler.

### Open questions for whichever path

- Does Monado's MR !2737 take the lease successfully once it's
  offered? Earlier logs showed `Available DRM lease device:
  /dev/dri/card1` so the lease device side works.
- Does WayVR render both eyes correctly in direct mode? Monado
  should handle SBS packing internally and the glasses' built-in
  3D mode toggle should fire when monado switches the output.
- WayVR's Handsfree mode (3DoF + no controllers) needs enabling
  through the dashboard — UX path TBD.
- Without keyboard/mouse in VR, how do we configure WayVR panels?
  Show hotkey on the desktop side; virtual keyboard overlay in VR.

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
