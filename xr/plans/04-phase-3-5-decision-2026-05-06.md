# Phase 3.5 — Diagnose `VK_ERROR_SURFACE_LOST_KHR` on first present

Started: 2026-05-06
Status: data collection in progress (v2 diagnostic queued)

## What this is

Phase 3 architecturally completed: EDID override flips `non_desktop=1`,
wlroots advertises the connector via `wp-drm-lease-v1`, monado takes
the lease, OpenXR session reaches FOCUSED. **First `vkQueuePresentKHR`
fails with `VK_ERROR_SURFACE_LOST_KHR`. Glasses stay black.**

This file logs what we tried, what each iteration learned, and what's
next. The original framing of this file ("decide which option to take
past the Mesa anv wall") was based on a misdiagnosis — see "What was
wrong" below.

## v1 diagnostic — 2026-05-06 (run.sh)

**Setup:** wrapped `breezy-hyprland` in a 5-second timeout with env
vars `MESA_VK_WSI_DEBUG=display`, `MESA_DEBUG=context`,
`ANV_DEBUG=video,sync`, `VK_LOADER_DEBUG=warn,error`. Captured
pre/post `drm_info`, `journalctl -k` over the run window, and the
monado log.

**What worked:**
- `vkCreateInstance` with display extensions
- `vkAcquireDrmDisplayEXT` on the leased Rayneo connector
- `vkCreateDisplayPlaneSurfaceKHR` — full surface caps reported
  (1920x1080 currentExtent, A2B10G10R10_UNORM_PACK32 supported)
- `vkCreateSwapchainKHR` — with `imageFormat = A2B10G10R10_UNORM_PACK32`,
  `imageUsage = STORAGE_BIT`, `presentMode = FIFO_KHR`
- `comp_target_swapchain_create_images` — vblank thread started

**What failed:**
- First `vkQueuePresentKHR`: `VK_ERROR_SURFACE_LOST_KHR`
  (monado log line 184: `[renderer_present_swapchain_image]`)
- Subsequent `vkAcquireNextImageKHR`: same error (surface dead)

**What v1 didn't tell us:**
- Zero `wsi_display` debug lines in the log — `MESA_VK_WSI_DEBUG=display`
  produced no output. Possible reasons: env var name wrong for this Mesa
  version, env var not propagated through `writeShellApplication`'s
  subshell, or the failing branch lacks debug prints.
- Zero kernel-side `i915` / DRM atomic errors in the run window —
  expected, since `drm.debug` is unset by default. The kernel doesn't
  log atomic_check failures at info level.

**Conclusion:** v1 confirmed setup succeeds, present fails. Cannot
distinguish kernel-side rejection from Mesa-internal early-return
without (a) raised kernel `drm.debug` and (b) confirmed-working Mesa WSI
debug.

## v2 diagnostic — designed 2026-05-06, awaiting execution (run-v2.sh)

**Changes vs v1:**
1. `sudo` writes `0x1f` to `/sys/module/drm/parameters/debug` for the run
   window (CORE+DRIVER+KMS+PRIME+ATOMIC); restored on exit. Kernel will
   now log atomic_check rejects to dmesg.
2. Both `MESA_VK_WSI_DEBUG=display` AND `WSI_DEBUG=display` exported
   (the Mesa binary contains both string literals; unclear which is
   wired in 26.0.6).
3. A wrapper `env | grep -E "^(MESA|WSI|ANV|VK_LOADER|XR_RUNTIME)"`
   confirms env vars actually propagate into the launch context.
4. `sudo dmesg` for the run window (kernel.dmesg_restrict=1 on lewis).

**Verified before this script was usable:**
- `libvulkan_intel.so` strings include `wsi_display_setup_crtc`,
  `wsi_display_setup_connector`, `_wsi_display_queue_next`,
  `wsi_display_queue_present`, `drmModeAtomicCommit`, and `VK_ERROR_SURFACE_LOST_KHR`.
  So Mesa anv DOES include the device-level WSI display path; it's
  not stub'd out. The failure is somewhere inside that path.

**Pending hypotheses to check from v2 output:**

| If kernel dmesg shows... | Then... |
|---|---|
| `intel_atomic_check` rejecting plane/CRTC/connector with EINVAL | i915 won't scan out the swapchain image (likely modifier/format/usage mismatch). Fix: coerce monado's swapchain usage flags or carry a Mesa patch for image allocation. |
| `drm` connector / mode logs but no atomic rejection | Mesa is failing pre-ioctl. Need to read `wsi_display_*` debug or instrument Mesa source. |
| Kernel still silent + no Mesa WSI output either | Failure is in a no-debug branch of Mesa — likely `wsi_display_setup_crtc` returning no CRTC, or `drmModeAddFB2WithModifiers` failing. Next step would be apitrace or a Mesa source dive. |

## What's still on the table after v2

- **A** — Carry a Mesa patch (cost depends on which Mesa code path is at
  fault; might be small if it's a usage-flag mismatch, large if it's
  an Intel display-engine quirk)
- **B** — Pivot to Wayland-windowed mode + solve the SBS rendering
  problem from Phase 2. The EDID + USB ACL fix from Phase 3 stays
  deployed regardless. ~Days of work; produces visible output sooner.
- **C** — Different OpenXR runtime (Linux OSS options are Monado or
  nothing — likely dead branch).

The choice depends on what v2 reveals.

## What was wrong (the misdiagnosis this file used to enshrine)

Original framing claimed Mesa anv on Intel Arc "advertises
`VK_KHR_display` at the instance level but does NOT implement the
device-level functions" and pointed at `vkcube --wsi display`'s
"Cannot find any display!" as proof. Two checks killed it:

1. The vulkaninfo warning we cited was emitted by the dzn ICD (which
   crashes during init), not anv. Forcing Vulkan to use ONLY the Intel
   ICD via `VK_DRIVER_FILES=` made the warning vanish.
2. Background research on Mesa source confirmed `wsi_common_display.c`
   has no anv-vs-radv asymmetry; the WSI display path is shared. The
   Intel ICD binary contains the full `wsi_display_*` symbol family.

Lesson: re-verify "X is impossible because of Y" before shipping it as
load-bearing. See `memory/process-verify-before-recommend.md`.

## References

- v1 diagnostic output: `.scratch/diagnose-surface-lost/` (gitignored)
- v2 diagnostic script: `.scratch/diagnose-surface-lost/run-v2.sh`
- Updated memory: `memory/xr-mesa-anv-display-gap.md`
- Architectural state: `xr/STATE.md` (lewis row)
- Phase 3 plan: `plans/03-hyprland-breezy-2026-05-06.md`
- LEARNINGS: `xr/LEARNINGS.md`
