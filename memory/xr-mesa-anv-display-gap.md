---
type: project
title: Mesa anv + Intel Arc — direct-mode WSI scanout (current best hypothesis: monado swapchain usage flags)
created: 2026-05-06
---

**This file's history is a chain of misdiagnoses. Read what's CURRENT
below before acting.**

## Current best hypothesis (2026-05-06, post launcher-fix + EDID 3840 + monado-patch)

The blank/streaky panel was **never** a Mesa anv gap. Two real issues
stack on top of each other:

1. **Launcher socket race** (FIXED, commit `f74154b`) — produced
   SURFACE_LOST-shaped symptoms because wayvr connected before
   monado-service had the IPC socket; the EXIT trap killed monado
   mid-frame. Stale `monado_comp_ipc` was the trigger. See
   `system/lib/xr/breezy-hyprland/launcher.nix`.
2. **monado allocates the WSI display swapchain with `VK_IMAGE_USAGE_STORAGE_BIT`
   only** when `use_compute=true` (the default on Linux,
   `comp_settings.c:13-17`). On Mesa anv, STORAGE-only pushes the
   image to a non-scanout-compatible tiling/modifier; KMS display
   planes can't address it; panel shows black/garbage even though
   the compute shader has filled the image.

## The fix being tested (NOT YET VERIFIED)

`system/lib/xr/monado-rayneo/patches/comp-renderer-scanout-compatible-tiling.patch`
pairs `VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT` with `STORAGE_BIT` on the
compute branch in `comp_renderer.c:543-549` of upstream monado. Patch
is wired into `system/lib/xr/monado-rayneo/package.nix`'s patches
array. Hypothesis: with both bits set, Mesa selects a
scanout-compatible modifier and the display planes can read the
compute-shader output.

**Status: applied, not yet verified.** Run breezy-hyprland after the
next rebuild; if the glasses show coherent stereo content (instead of
left-half-black + right-half-rainbow), the hypothesis holds. If
SURFACE_LOST still appears, investigate Mesa's `wsi_common_display.c`
modifier negotiation path.

## Diagnostic findings that supported this hypothesis

- v4 run with `XRT_COMPOSITOR_COMPUTE=0` (forces graphics path that
  already had `COLOR_ATTACHMENT_BIT`) reached FOCUSED, IPD=63mm, NO
  SURFACE_LOST. (It then SEGV'd in wayvr — separate issue, but the
  swapchain present cycle was clean.) This localized the failure to
  the compute-path swapchain usage flags.
- `comp_settings.c:37` defines `XRT_COMPOSITOR_COMPUTE` env var via
  `DEBUG_GET_ONCE_BOOL_OPTION`. `rayneo_hmd.c:923` sets
  `screens[0].w_pixels = panel_w * view_count` (1920*2=3840),
  confirming why monado wants the 3840 mode.
- v3 diagnostic also revealed `MESA_VK_WSI_DEBUG=display` is a no-op
  because Mesa's `wsi_display_debug` macro is `#if 0`'d. See
  `xr-mesa-wsi-debug-disabled.md`.

## Side-effect to watch: Hyprland safe-mode after EDID 3840 mode

Commit `7122089` added a 3840x1080@60 DTD to the patched EDID so
monado renders SBS at native. After reboot with this EDID, Hyprland
intermittently crashes into safe-mode during lease cycles. Aquamarine
logs show `drm: Cannot commit when a page-flip is awaiting`. Suspected
CDCLK contention from the new mode. Open issue, separate from the
swapchain fix.

## What we have available

- `libvulkan_intel.so` strings include the full `wsi_display_*` symbol
  family. Mesa anv DOES implement device-level display WSI — original
  "missing functions" claim was WRONG.
- `libRayNeoXRMiniSDK.so` exposes `SwitchTo2D` / `SwitchTo3D`.
  xr-driver control IPC: `printf 'sbs_mode=enable\n' > /dev/shm/xr_driver_control`
  toggles glasses' SBS mode (see `xr-rayneo-hardware.md`).
- v1, v2, v3 diagnostic outputs in `.scratch/diagnose-surface-lost/`
  (gitignored). v4 is the graphics-path comparison.
- Offline OSS source corpus at `.research/` — see
  `xr-research-corpus.md`. Contains Mesa, monado, kernel DRM,
  Hyprland v0.54.3, wlroots, Aquamarine, gamescope, wivrn.

## What was wrong (the original misdiagnosis)

Original framing — "Mesa anv doesn't implement `VK_KHR_display` device
functions, vkcube fails the same way" — was based on misreading a
vulkaninfo warning emitted by the **dzn** ICD (which crashes during
init), not anv. Forcing Vulkan to use ONLY the Intel ICD via
`VK_DRIVER_FILES=` made the warning vanish. Mesa source has no
anv-vs-radv asymmetry in `wsi_common_display.c`.

Lesson: re-verify "X is impossible because of Y" before treating it
as load-bearing. See `process-verify-before-recommend.md`.

## What this rules out (still true)

- "Use a different OpenXR runtime that does direct mode" — they all
  go through Mesa WSI on Linux
- "Tweak monado's compositor backend selection" — only one backend
  (`comp_window_direct_wayland`) is being tried; no alternative
- "Adjust EDID modes / refresh / colorspace" without first knowing
  which layer (i915 vs Mesa vs monado) rejects what — would be
  guessing
