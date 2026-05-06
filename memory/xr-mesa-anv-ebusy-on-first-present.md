---
type: project
title: Mesa anv first-present atomic_commit returns EBUSY → SURFACE_LOST
created: 2026-05-07
---

Canonical entry for the actual finding behind the Round 2 / Round 3
SURFACE_LOST loop on `lewis` (Intel Arc, Mesa anv, breezy-hyprland +
monado-rayneo + glasses-edid). Companion to
`xr-mesa-anv-display-gap.md` (full investigation log) and
`xr-mesa-wsi-debug-disabled.md` (why we needed strace at all).

## The single failing ioctl

Captured via the v2 strace runner at
`.scratch/wayvr-trace/run-strace-v2.sh` on a clean post-reboot
2026-05-07 run. Strace files at
`.scratch/wayvr-trace/strace-monado-20260507-002455.log.<tid>`,
thread `30914`:

```
00:25:04.008900  ioctl(17</dev/dri/card1>, DRM_IOCTL_MODE_CREATEPROPBLOB, ...)  = 0
00:25:04.009076  ioctl(17</dev/dri/card1>, DRM_IOCTL_MODE_ATOMIC, ...)          = -1 EBUSY (Device or resource busy)
00:25:04.010479  write(2, "ERROR [renderer_present_swapchain_image] vk_swapchain_present: VK_ERROR_SURFACE_LOST_KHR\n", ...)
```

The property blob for the modeset is created cleanly. The very next
atomic commit (the one that actually drives the modeset) returns
`EBUSY`. Mesa returns `VK_ERROR_SURFACE_LOST_KHR`. Monado has no
retry path; subsequent threads block in
`drm_syncobj_array_wait_timeout` waiting for fences that never
signal.

## Mesa source (where the errno is lost)

- `mesa/src/vulkan/wsi/wsi_common_display.c:2855` — atomic_commit
  builder for the modeset path (`ALLOW_MODESET | PAGE_FLIP_EVENT |
  NONBLOCK` flags on the commit).
- `mesa/src/vulkan/wsi/wsi_common_display.c:3122-3134` — the
  `if (ret != -EACCES)` branch that translates **any** non-EACCES
  atomic_commit failure to `VK_ERROR_SURFACE_LOST_KHR`. EBUSY,
  EINVAL, ENOSPC, EIO — all become "surface lost" to Vulkan callers.
  `wsi_display_debug` could log the original errno but is
  `#if 0`'d; see `xr-mesa-wsi-debug-disabled.md`.

## Monado source (where the lack of retry hurts)

In `.research/src/monado/src/xrt/compositor/main/comp_renderer.c`:

- `renderer_present_swapchain_image` — logs SURFACE_LOST and
  returns it up the stack with no retry.
- `renderer_acquire_swapchain_image` — same, no retry on
  SURFACE_LOST. Only `VK_ERROR_OUT_OF_DATE_KHR` triggers a retry
  (around `comp_renderer.c:747`).

Net: the first kernel EBUSY is fatal to the present cycle. The OpenXR
session keeps running (head pose still flowing, IPD reported), but
no further frames present, glasses stay black.

## Why this matters

Every "glasses are black" report on `lewis` with both `3bf13da`
(swapchain usage flags) and `7122089` (EDID 3840x1080 mode) active is
now traceable to this one ioctl returning EBUSY. The earlier
hypotheses (display-plane gap, swapchain usage flags, EDID mode) are
all genuine fixes for genuine bugs, but none of them are what's
currently keeping the panel dark. This one is.

## Leading hypothesis for WHY EBUSY (NOT confirmed)

CRTC contention with Hyprland. Mesa's `wsi_display_select_crtc`
at `wsi_common_display.c:2260-2289` first tries the CRTC currently
bound to the connector's encoder, then falls back to any CRTC with
`buffer_id == 0`. Aquamarine's `SDRMConnector::connect` at
`.research/src/aquamarine/src/backend/drm/DRM.cpp:1646` assigns CRTC
267 to DP-2 internally even on the non_desktop early-return path
(Hyprland's `Monitor.cpp:246` doesn't undo aquamarine's CRTC
binding). When monado's lease commits to that same CRTC, the kernel
may return EBUSY because of the existing binding from Hyprland's
compositor side. Not yet verified by reading the failing atomic
blob's CRTC ID.

## Reproducer

```fish
bash .scratch/wayvr-trace/run-strace-v2.sh   # glasses connected pre-launch
```

Then grep the resulting strace files:

```fish
grep 'DRM_IOCTL_MODE_ATOMIC.*= -1 E' .scratch/wayvr-trace/strace-monado-*.log.*
```

If you see `EBUSY` on a `DRM_IOCTL_MODE_ATOMIC` line followed shortly
by a `VK_ERROR_SURFACE_LOST_KHR` write, this is the same bug.

## What to try next

See the Round 3 section of `xr-mesa-anv-display-gap.md` for the
ordered next-step list (confirm CRTC theory, monado retry-on-failure,
Mesa errno translation to `VK_NOT_READY`, clear Hyprland's stale CRTC
binding pre-launch).

## Companion files

- `memory/xr-mesa-anv-display-gap.md` — full investigation log,
  Round 1 (misdiagnosis) → Round 2 (SURFACE_LOST resurfaces) →
  Round 3 (this finding).
- `memory/xr-mesa-wsi-debug-disabled.md` — why
  `MESA_VK_WSI_DEBUG=display` is silent and strace was needed to see
  the kernel errno.
- `xr/STATE.md` — lewis row's open issue (a) cites this file.
- `xr/LEARNINGS.md` — "EBUSY on atomic_commit means CRTC contention
  (or transient flip), not surface-lost" entry.
