# Phase 3.5 — Diagnose `VK_ERROR_SURFACE_LOST_KHR` on first present

Started: 2026-05-06
Status: launcher race fixed (commit `f74154b`); SURFACE_LOST + content
issues remain; offline OSS source corpus being built at `.research/`

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

## v2 diagnostic — executed 2026-05-06 (run-v2.sh)

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

**v2 result:** kernel dmesg showed monado-service issues exactly one
`DRM_IOCTL_MODE_ATOMIC` per swapchain present, kernel runs full mode
setup (CDCLK, DPLL alloc, plane state), `intel_atomic_check` passes,
DP link trains successfully (`Channel EQ done`, `Link Training passed
at link rate = 270000, lane count = 4`), pipe C enables, audio codec
enables, `verify_connector_state DP-2` passes — **zero
atomic_check rejection, zero EINVAL returns from monado-service
ioctls in the run window.** Whatever causes SURFACE_LOST is NOT a
kernel-side rejection.

The Mesa WSI debug envs (`MESA_VK_WSI_DEBUG=display`, `WSI_DEBUG=display`)
produced no output even when confirmed-inherited — the failing branch
of Mesa's display WSI either lacks debug prints or uses a different
gating env.

## v3 diagnostic — executed 2026-05-06 (run-v3-nosudo.sh, 15s window)

The 5s window of v1+v2 killed monado before its first present landed.
v3 ran 15s, no sudo (kernel debug already characterized).

**v3 result revealed a different bug entirely:** monado log ended
with `Server exiting: '0'` and breezy-stdout showed wayvr's
`Failed to connect to socket /run/user/1000/monado_comp_ipc:
Connection refused!`. The monado-service log line right before init
completion was `WARN [create_listen_socket] Removing stale socket
file /run/user/1000/monado_comp_ipc` — smoking gun.

Root cause: launcher's socket-wait loop saw the stale socket from a
previous run, broke immediately, and launched wayvr before
monado-service had finished init. monado-service then removed the
stale socket and created its own — but wayvr already got
ECONNREFUSED, exited clean, EXIT trap killed monado mid-frame.
SURFACE_LOST in v1 was a downstream symptom of monado being killed
before it could even attempt a real present cycle.

**Fix:** `rm -f` the stale socket alongside the existing `monado.pid`
cleanup in `system/lib/xr/breezy-hyprland/launcher.nix`. Commit
`f74154b`. FIXES.md entry under "2026-05-06 — breezy-hyprland-stale-monado-ipc-socket-race".

## Post-fix state — what remains

After the launcher fix, behavior depends on the run:

- **One v3 run hit steady-state present:** 65 frames over 15s
  (~60fps effective at 120Hz target — frame-timing warnings, no
  actual errors). Wayvr connected as Client 1, ran cleanly,
  disconnected on SIGINT.
- **Subsequent runs revert to first-present `VK_ERROR_SURFACE_LOST_KHR`.**
  Same code, same env, different outcome — strongly intermittent.

**Visual output when scanout lands:** "left half black, right half
rainbow vertical streaks." Two contributing factors:
1. monado wants 3840x1080 SBS surface; EDID forces 1920x1080;
   glasses (in 3D mode) split the 1920-wide signal expecting SBS,
   getting wrong-resolution-per-eye content
2. monado's `STORAGE_BIT`-only swapchain → Mesa picks
   compute-optimal tiling → DRM `MODE_ADDFB2` (modifier-less)
   defaults to linear → tile pattern scanned out as RGB

## What's still on the table

- **A** — Add 3840x1080 DTD to patched EDID. Then monado renders
  at native SBS resolution. Glasses in 3D mode receive what they
  expect. Might fix both the resolution-per-eye AND the
  intermittent SURFACE_LOST if the latter is somehow tied to
  Mesa's mode-switching path.
- **B** — Patch monado swapchain create to add
  `VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT`. Forces Mesa to allocate
  scanout-compatible tiling. Should fix the rainbow streaks.
- **C** — Both A and B (likely needed together).
- **D** — Read Mesa source via the `.research/` corpus to
  understand what `wsi_display_image_init` does with usage flags.
  Then make an informed patch decision.

The offline corpus build is queued — see `.research/INDEX.md`
(once written by the bg agent).

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
