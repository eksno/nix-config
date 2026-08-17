# Hyprland-breezy via Monado + WayVR (open-source replacement)

Started: 2026-05-05
Status: Phase 1 + Phase 2 plumbing shipped. Phase 3 (DRM direct lease via
        EDID non-desktop override) implemented 2026-05-06; awaits a
        reboot to verify the patched EDID is loaded by the kernel and
        wlroots advertises the connector for lease. Launcher already in
        the right state (no monitor toggle, just hygiene fixes).

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

### Real Phase 3: EDID override to force non-desktop (IMPLEMENTED, awaiting post-reboot verification)

The clean architectural fix: make the glasses look like a non-desktop
output to wlroots from boot. Implemented via the kernel's
`drm.edid_firmware=` mechanism — a patched EDID is placed at
`/lib/firmware/edid/rayneo-air4pro-glasses.bin` and the kernel uses
it instead of probing the connector.

**What shipped (commit TBD):**

- `xr/edid/glasses-original.bin` — captured original EDID from
  `/sys/class/drm/card1-DP-2/edid`. 256 bytes, base EDID 1.3 + one
  CTA-861 extension, no non-desktop signaling.
- `xr/edid/patch_glasses_edid.py` — Python tool that inserts a
  Microsoft HMD Vendor-Specific Data Block into the CTA-861
  extension. The Linux DRM subsystem
  (`cea_db_is_microsoft_vsdb` in `drivers/gpu/drm/drm_edid.c`)
  recognizes the OUI 0x5C 0x12 0xCA + 21-byte payload and sets
  `connector.non_desktop = true` on parse. Tool also bumps the DTD
  start offset, shifts DTDs forward, and recomputes the CTA-861
  checksum.
- `xr/edid/glasses-nondesktop.bin` — patched output. Verified with
  `edid-decode`: DTDs preserved, checksum valid, "Vendor-Specific
  Data Block (Microsoft), OUI CA-12-5C, Version: 2" parsed
  correctly.
- `system/lib/xr/glasses-edid/default.nix` — NixOS module installing
  the patched EDID via `hardware.firmware` and adding
  `boot.kernelParams = [ "drm.edid_firmware=DP-2:edid/rayneo-air4pro-glasses.bin" ]`.
- `system/hosts/lewis/default.nix` — imports `glasses-edid`.

NixOS builds clean; kernel cmdline confirmed to include the
`drm.edid_firmware=` token; the patched EDID is deployed at
`/run/current-system/firmware/edid/rayneo-air4pro-glasses.bin.zst`
(NixOS zstd-compresses firmware blobs; kernel auto-decompresses).

### Post-reboot verification checklist

After `./update.sh` + reboot (the new EDID is loaded by the kernel
at boot; no live re-probe will flip the bit):

1. **EDID was substituted:**
   ```
   diff <(cat /sys/class/drm/card1-DP-2/edid) \
        /home/jorge/nix-config/xr/edid/glasses-nondesktop.bin
   ```
   Should be silent (identical).

2. **Non-desktop bit is set:**
   ```
   cat /sys/class/drm/card1-DP-2/non_desktop
   ```
   Should print `1`.

3. **Hyprland skips the connector:**
   ```
   hyprctl monitors          # should NOT list DP-2 / SmartGlasses
   hyprctl monitors all      # may still list it as a known but
                             # non-managed connector
   ```

4. **wlroots advertises the connector for lease.** Hard to test
   directly without running monado, but the next step does.

5. **Run `breezy-hyprland`.** monado log
   (`/run/user/1000/monado-service.log`) should now show
   `Selected DRM lease device: /dev/dri/card1` followed by a
   real connector being leased — NOT the previous
   `Found no connectors available for direct mode`.

6. **Visual:** glasses should now show stable VR rendering
   (passthrough background + WayVR overlays) instead of the
   half-rainbow Phase 2 symptoms.

### Tradeoff and rollback

While the override is active, the glasses **do not appear as a normal
Hyprland monitor** — they're VR-only. For Jorge's XR-first workflow
this is the goal; the rare "use as regular external monitor" case
can revert by removing the import line in `system/hosts/lewis/default.nix`
and rebuilding+rebooting (the kernel param goes away on the next
generation).

If the post-reboot verification fails (e.g. kernel rejects the EDID
blob, glasses fail to enumerate), boot the previous generation from
the systemd-boot menu and remove the import.

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
