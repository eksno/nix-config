---
type: project
title: Mesa anv + Intel Arc — direct-mode WSI scanout (Round 3: kernel returns EBUSY on first atomic_commit; Mesa hides it as SURFACE_LOST)
created: 2026-05-06
updated: 2026-05-07
---

**This file's history is a chain of misdiagnoses. Read what's CURRENT
below before acting.**

## Round 3 (2026-05-07): Root cause located — kernel `EBUSY` on first `DRM_IOCTL_MODE_ATOMIC`

**The "first-present modeset failing for unknown reason" framing from
Round 2 is now obsolete.** We know what fails and why Mesa hid it.

The single failing ioctl, captured via the v2 strace runner at
`.scratch/wayvr-trace/run-strace-v2.sh` on a clean post-reboot run
(strace files at `.scratch/wayvr-trace/strace-monado-20260507-002455.log.<tid>`,
thread `30914`):

```
00:25:04.008900  ioctl(17</dev/dri/card1>, DRM_IOCTL_MODE_CREATEPROPBLOB, ...)  = 0
00:25:04.009076  ioctl(17</dev/dri/card1>, DRM_IOCTL_MODE_ATOMIC, ...)          = -1 EBUSY (Device or resource busy)
00:25:04.010479  write(2, "ERROR [renderer_present_swapchain_image] vk_swapchain_present: VK_ERROR_SURFACE_LOST_KHR\n", ...)
```

Chain:
1. Mesa wsi_display creates the property blob for the modeset (succeeds).
2. Submits the atomic commit with `ALLOW_MODESET | PAGE_FLIP_EVENT |
   NONBLOCK` (`mesa/src/vulkan/wsi/wsi_common_display.c:2855-2947`).
3. Kernel returns `EBUSY`.
4. Mesa hits the `if (ret != -EACCES)` branch at
   `wsi_common_display.c:3129-3134` and returns `VK_ERROR_SURFACE_LOST_KHR`.
   The original `errno` is **not propagated** — every non-`EACCES`
   atomic_commit failure flattens to SURFACE_LOST.
5. Monado logs the error but has no retry path for SURFACE_LOST in
   `comp_renderer.c renderer_present_swapchain_image`.
6. Subsequent monado threads (most painfully thread 71515 / equivalent
   in this run) end up in `drm_syncobj_array_wait_timeout` waiting for
   fences that will never signal → process deadlocks.

We needed strace to see the kernel errno because Mesa's
`wsi_display_debug` macro is compiled out — see
`memory/xr-mesa-wsi-debug-disabled.md`.

**Leading hypothesis (NOT confirmed) for WHY EBUSY:** CRTC contention
with Hyprland. Mesa's `wsi_display_select_crtc` at
`wsi_common_display.c:2260-2289` first tries the CRTC currently bound
to the connector's encoder, then falls back to any CRTC with
`buffer_id == 0`. Aquamarine's `SDRMConnector::connect` at
`.research/src/aquamarine/src/backend/drm/DRM.cpp:1646` assigns CRTC
267 to DP-2 internally even on the non_desktop early-return path
(Hyprland's `Monitor.cpp:246` doesn't undo aquamarine's CRTC binding).
When monado's lease commits to that same CRTC, the kernel may return
EBUSY because of the existing binding from Hyprland's compositor side.
Not yet verified by reading the failing atomic blob's CRTC ID; treat
as the leading hypothesis pending confirmation.

Canonical entry for the finding:
`memory/xr-mesa-anv-ebusy-on-first-present.md`.

### What to try next (ordered)

1. **Confirm CRTC theory.** Read the failing atomic blob's `CRTC_ID`
   from the strace dump (the prop array passed to `DRM_IOCTL_MODE_ATOMIC`
   at the EBUSY call). If it's CRTC 267, contention with Hyprland's
   stale aquamarine binding is confirmed.
2. **Patch monado to retry on first-present failure.**
   `comp_renderer.c renderer_present_swapchain_image` currently has
   no retry on SURFACE_LOST (only OUT_OF_DATE retries near
   `comp_renderer.c:747`). If EBUSY is transient (e.g. a page-flip in
   flight clears), a simple retry should succeed.
3. **Patch Mesa wsi_display to translate EBUSY → `VK_NOT_READY`**
   rather than SURFACE_LOST — EBUSY isn't "surface lost", it's "try
   again later". Lets monado retry via normal swapchain timing without
   pretending the surface died.
4. **Find a way to clear Hyprland's stale CRTC binding for non_desktop
   connectors before launching monado** — e.g., a Hyprland patch to
   skip CRTC assignment entirely for non_desktop, or a runtime way to
   clear it before lease handover.

## Round 2 (2026-05-06 evening): SURFACE_LOST has REAPPEARED in a different form

**(Superseded by Round 3 above — kept for log continuity.)**

After the rolled-back gen booted (`549bd84`, the gen with both
`3bf13da` swapchain-usage and `7122089` EDID-3840 patches active), a
breezy-hyprland run with the glasses already connected reached
FOCUSED, kept rendering frames, but **monado hit
`VK_ERROR_SURFACE_LOST_KHR` on first present and stopped trying** —
two SURFACE_LOST entries total (one from `vk_swapchain_present`, one
from `comp_target_acquire`), then silence. No retry, no further
present attempts.

**Both prior monado fixes are confirmed active in this build** (so
this is not a regression of either fix):

- swapchain log shows `imageUsage: STORAGE_BIT + COLOR_ATTACHMENT_BIT`
  — `3bf13da` is in
- swapchain log shows `imageExtent: {3840, 1080}` — EDID 3840x1080
  mode injection from `7122089` is working

`/sys/class/drm/card1-DP-2/enabled = disabled` while monado held the
lease — connector was leased but never modeset by Mesa wsi_display.

This is a **different SURFACE_LOST** than the one `3bf13da` addressed.
The earlier fix targeted swapchain creation (compute-path image was
non-scanout-compatible). This new failure happens at first present
despite the swapchain creating cleanly with the right usage flags and
extent. Suspect Mesa's `wsi_common_display.c` modeset/page-flip path.

Saved monado log copy at
`.scratch/wayvr-trace/monado-200645.log`. Run logs at
`.scratch/wayvr-trace/run-20260506-200645.log` and
`run-20260506-200603.log`.

**Do not** re-blame swapchain usage flags or EDID mode injection —
both are verified working in this build.



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
- v3 re-run after the swapchain-usage patch landed (2026-05-06,
  post-`3bf13da`): monado runs cleanly end-to-end — both wayvr OpenXR
  clients connect, swapchain creates, frames present at ~30 fps with
  "missed frame by 16ms" warnings, both clients eventually disconnect
  normally. **No SURFACE_LOST.** Monado-side hypothesis verified;
  user-facing "see something on the glasses" outcome remains gated on
  the wayvr crash described below.

## Pending hypothesis: wayvr GPU-capture (DMA-BUF) crash on Mesa anv

After the monado fix landed, breezy-hyprland still leaves the panel
black because `wayvr` segfaults right after FOCUSED. In the latest v3
log (`.scratch/diagnose-surface-lost/breezy-stdout-v3.txt`), the last
two log lines are:

  - `entered state FOCUSED` (`wayvr/src/backend/openxr/mod.rs:169`)
  - `Using GPU capture. ... switch 'Wayland capture method' to a CPU
    option!` (`wayvr/src/overlays/screen/backend.rs:200`)

…then `Segmentation fault (core dumped) wayvr --openxr --show`.
Code at `backend.rs:200-217` shows the warning is emitted just before
`MyFirstDmaExporter::new(...)` and `self.capture.init(...)` — i.e.
the wlr_screencopy_v1 → DMA-BUF → Vulkan import path. Suspected:
modifier mismatch when vulkano imports the DMA-BUF on anv.

**Important: the prior agent attributed the segfault to wgui's
"Grow Color atlas 256 → 512" log line at `text_atlas.rs:190`** (last
line in v4) and shipped a workaround in commit `b02dffa` that bumps
the initial atlas size from 256 → 2048 so growth never happens. The
patch DID prevent the grow path (the post-patch v3 log shows NO
`Grow Color atlas` line) but **wayvr still segfaults at the same wall-
clock distance from FOCUSED**, on `lewis` (Mesa anv 26.0.6 +
Hyprland 0.54.3 + wayvr 26.2.1). The atlas-grow log was *coincident*,
not *causal*: it was the previous log line, not the previous function
call. See `xr-wayvr-gpu-capture-segfault.md` for the full hypothesis
and what to test next.
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
