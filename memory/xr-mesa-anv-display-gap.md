---
type: project
title: Mesa anv + Intel Arc — direct-mode VR present-time SURFACE_LOST (under investigation)
created: 2026-05-06
---

**This file's history is a chain of misdiagnoses. Read what's CURRENT
below before acting.**

## What we know now (2026-05-06, post-v3 + launcher-race fix)

On `lewis` (Intel Arc Graphics MTL, Mesa 26.0.6, Hyprland), monado's
direct-mode display WSI path:

- ✅ Vulkan instance + display extensions
- ✅ `vkAcquireDrmDisplayEXT` on leased Rayneo connector
- ✅ `vkCreateDisplayPlaneSurfaceKHR` succeeds (1920x1080)
- ✅ `vkCreateSwapchainKHR` succeeds (`A2B10G10R10_UNORM_PACK32`,
  `STORAGE_BIT` only, FIFO)
- ✅ vblank thread starts
- ✅ Kernel-side modeset on DP-2 succeeds — DP link trains at
  `link rate = 270000, lane count = 4`, pipe C enables, audio codec
  enables, `verify_connector_state DP-2` passes (verified with
  `drm.debug=0x1f` in v2 diagnostic)
- ⚠️ First `vkQueuePresentKHR`: **mostly returns `VK_ERROR_SURFACE_LOST_KHR`.**
  But **one v3 run hit steady-state present (65 frames at 120Hz target,
  zero SURFACE_LOST)** — the failure mode is intermittent
- 🌈 When scanout DOES land on the glasses, content is **"left half
  black, right half rainbow vertical streaks"** — classic memory-layout
  mismatch (tiled GPU image scanned out as linear, OR resolution
  mismatch where only half the panel gets a coherent signal)

## The launcher race (now FIXED)

A separate failure mode that produced symptoms looking like SURFACE_LOST:
the launcher's socket-wait loop saw a stale `monado_comp_ipc` from a
previous run, broke immediately, and launched wayvr before
monado-service finished init. Wayvr got `Connection refused`, exited
clean, EXIT trap killed monado mid-frame. Fix: `rm -f` the stale
socket in the launcher (commit `f74154b`, FIXES.md entry).

Post-fix, monado actually reaches the present cycle — but the
SURFACE_LOST and the rainbow-streak content issue both remain.

## Suspect causes (still under investigation)

1. **Storage-only swapchain → tiling mismatch.** monado requests
   `VK_IMAGE_USAGE_STORAGE_BIT` only (no `COLOR_ATTACHMENT_BIT`,
   no `TRANSFER_DST_BIT`). Mesa allocates a compute-shader-optimal
   tiled image; DRM scans it out as linear; rainbow streaks. Likely
   fix: patch monado to add `COLOR_ATTACHMENT_BIT` to swapchain usage.
2. **Resolution mismatch.** monado wants 3840x1080 SBS (`Ignoring
   given extent 3840x1080 and using 1920x1080 from mode`). Glasses
   in 3D mode expect SBS too. Result: both eyes get only-half-image
   content. Likely fix: add a 3840x1080 DTD to the patched EDID so
   Mesa exposes it as a valid display mode.
3. **Race in Mesa's wsi_display present path.** The SURFACE_LOST is
   intermittent — succeeded once, fails most other runs. Could be
   syncobj/fence ordering, or the page-flip event not arriving in time.

## What we have available

- `libvulkan_intel.so` strings include the full `wsi_display_*` symbol
  family (`wsi_display_setup_crtc`, `_wsi_display_queue_next`,
  `wsi_display_queue_present`, `drmModeAtomicCommit`,
  `VK_ERROR_SURFACE_LOST_KHR`). Mesa anv DOES implement device-level
  display WSI — original "missing functions" claim was WRONG.
- `libRayNeoXRMiniSDK.so` exposes `SwitchTo2D` / `SwitchTo3D`.
  xr-driver control IPC: `printf 'sbs_mode=enable\n' > /dev/shm/xr_driver_control`
  toggles glasses' SBS mode (see `xr-rayneo-hardware.md`).
- v1, v2, v3 diagnostic outputs in `.scratch/diagnose-surface-lost/`
  (gitignored)

## How to make further progress

Before patching anything, the offline source corpus at
`.research/` (per Jorge's "import all OSS repos" request) gives us
Mesa's `wsi_common_display.c`, monado's `comp_target_swapchain.c`,
and Linux i915 atomic check source — read those for the exact
swapchain image allocation path before guessing.

Re-run the v3 diagnostic via `.scratch/diagnose-surface-lost/run-v3-nosudo.sh`
after waking glasses. Multiple runs needed to characterize the
SURFACE_LOST intermittency.

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
