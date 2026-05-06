---
type: project
title: Mesa anv + Intel Arc — direct-mode VR present-time SURFACE_LOST (under investigation)
created: 2026-05-06
---

**Important:** This file used to claim Mesa anv has zero `VK_KHR_display`
device-level implementation. **That was wrong** — see "What was wrong" at
the bottom. Read this file's *current* claims, not the old ones.

## What we know now (2026-05-06, after diagnostic v1)

On `lewis` (Intel Arc Graphics MTL, Mesa 26.0.6), monado's direct-mode
display WSI path:

- ✅ `vkCreateInstance` with `VK_KHR_display`, `VK_EXT_acquire_drm_display`,
  `VK_EXT_direct_mode_display` succeeds
- ✅ `vkAcquireDrmDisplayEXT` on the leased Rayneo connector succeeds
- ✅ `vkCreateDisplayPlaneSurfaceKHR` succeeds — surface gets full caps
  reported (1920x1080, A2B10G10R10_UNORM_PACK32 supported, etc.)
- ✅ `vkCreateSwapchainKHR` succeeds — vblank thread starts
- ❌ **First `vkQueuePresentKHR` returns `VK_ERROR_SURFACE_LOST_KHR`**
- ❌ Subsequent `vkAcquireNextImageKHR` also returns SURFACE_LOST (surface
  is dead after the failed present)

The Mesa binary `libvulkan_intel.so` does contain the `wsi_display_*`
function family (`wsi_display_setup_crtc`, `wsi_display_setup_connector`,
`_wsi_display_queue_next`, `wsi_display_queue_present`, etc.) and a
`drmModeAtomicCommit` reference. So Mesa anv DOES implement the device-level
display WSI. The failure is somewhere inside that path on the first present.

## Suspect causes (not yet confirmed)

1. **i915 atomic_check rejects the plane configuration.** Display planes
   may not accept the swapchain image's tiling/modifier or format. monado
   requests `VK_IMAGE_USAGE_STORAGE_BIT` only — Mesa might allocate a
   non-scanout-friendly image and fail at present time when binding it
   to the plane. drm.debug=0x1f at the kernel will surface this.
2. **Mesa-internal early-return** — `wsi_display_setup_crtc` returns no
   CRTC, or `drmModeAddFB2WithModifiers` fails on the chosen image. Would
   produce kernel silence; only `WSI_DEBUG=display` / `MESA_VK_WSI_DEBUG=display`
   would catch it.
3. **Mode mismatch.** Patched EDID exposes only one mode (1920x1080@60).
   monado picks it, but that mode may not actually be drivable on this
   connector via the Vulkan WSI atomic path (vs. the kernel modeset path
   used by wlroots).

## How to make progress (the diagnostic that actually works)

`/home/jorge/nix-config/.scratch/diagnose-surface-lost/run-v2.sh` raises
`drm.debug=0x1f` for the run window AND sets both `MESA_VK_WSI_DEBUG=display`
and `WSI_DEBUG=display` (Mesa binary contains both names; unclear which is
wired). It captures `sudo dmesg` for the run window. Run it after waking
the glasses (DP-2 must read `connected`). Output lands in the same
directory.

The *previous* diagnostic (v1, no kernel debug) confirmed surface and
swapchain creation succeed; failure is at present time. v2 is needed to
identify which side (Mesa vs i915) rejects what.

## What was wrong (the misdiagnosis)

The original framing — "Mesa anv doesn't implement `VK_KHR_display`
device functions, vkcube fails the same way" — was based on misreading
a vulkaninfo warning. Two independent verifications killed it:

1. Forcing Vulkan to use ONLY the Intel ICD via `VK_DRIVER_FILES=` made
   the warning disappear; the warning had been emitted by the dzn ICD
   (which crashes during init), not anv.
2. Background research on the Mesa source confirmed `wsi_common_display.c`
   has no anv-vs-radv asymmetry — the WSI display path is shared.

The memory was written before those checks ran. Lesson: re-verify before
treating "X is impossible because of Y" as load-bearing — see
`process-verify-before-recommend.md`.

## What this rules out (still true)

These approaches are dead regardless of root cause:
- "Use a different OpenXR runtime that does direct mode" — they all go
  through Mesa WSI on Linux
- "Tweak monado's compositor backend selection" — only one backend
  (`comp_window_direct_wayland`) is being tried; no alternative
- "Adjust EDID modes / refresh / colorspace" without first knowing which
  layer (i915 vs Mesa vs monado) rejects what — would be guessing
