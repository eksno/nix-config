---
type: project
title: Hyprland event-loop stall during DP-2 hot-plug while monado is leasing
created: 2026-05-06
---

A Hyprland safe-mode crash mode distinct from the CDCLK-overrun one
documented in `xr-hyprland-cdclk-cap.md`. Same host (`lewis`), same
EDID-non-desktop DP-2, same monado leasing — but a different signature
in the dead log and a different (unconfirmed) root cause.

## Symptom

Hyprland watchdog SIGABRTs ~8 seconds after `breezy-hyprland` launch
when Jorge puts on the glasses, ending the session in safe-mode on
the next compositor launch. The crash time is mid-init of the lease,
not steady-state.

## Evidence (2026-05-06 22:41 crash)

Dead log `/run/user/1000/hypr/521ece...1778072203_*/hyprland.log`:

- `line 16182` — hot-plug event arrives for DP-2
- `line 16204` — aquamarine: `Skipping connector DP-2, has crtc 267
  and is connected`
- `line 16212` — `Connector DP-2 connected`
- `line 16213` — `Connecting connector DP-2, CRTC ID 267` (entry into
  `SDRMConnector::connect()`)
- `lines 16214-16216` — connector mode dump cuts off mid-iteration
  (`Mode 0`, `Mode 1`, ...)
- coredump SIGABRT at 22:41:09 (8s after wayvr launch at 22:41:01)

`SDRMConnector::connect()` lives at
`.research/src/aquamarine/src/backend/drm/DRM.cpp:1646`. The function
is internal data-setup (populating mode list, reading EDID blob,
attaching props) — **not** a kernel modeset.

## What this is NOT

Each of these has hard evidence against it from the same session log:

- **NOT CDCLK overrun.** External monitor (HDMI-A-1) was disconnected
  at crash time per `line 9415` onward. With eDP-1@2880x1800x120 +
  DP-2@3840x1080x60 active, bandwidth was ~870 MP/s, under the ~1 GP/s
  ceiling. No `Cannot commit when a page-flip is awaiting` lines
  adjacent to the crash. The CDCLK pathology DID hit earlier in the
  same session (`lines 5411-5585`) when external was plugged, but
  that's not what killed Hyprland this time.
- **NOT "Hyprland ignoring `non_desktop`."** Aquamarine logs
  `drm: Non-desktop connector` 4 times in the same session
  (`lines 1984, 2549, 3041`, plus one more) — the kernel non_desktop
  bit is being detected. wp-drm-lease was granted to monado at
  `lines 2580-2583` (`drm lease: output DP-2 ... lease granted with
  lessee id 2`). EDID + kernel + aquamarine all working as intended.
- **NOT a kernel modeset hang.** The `Connecting connector DP-2`
  log line is internal aquamarine data-setup at `DRM.cpp:1646`, not
  a `drmModeAtomicCommit`. No DRM ioctl is in flight at the stall
  point per the log.

## Leading hypothesis (NOT confirmed)

Event-loop stall inside `SDRMConnector::connect()`. Two candidates:

1. **`getDRMPropBlob(... props.values.edid ...)` at
   `DRM.cpp:1726`** — Hyprland synchronously reads the EDID blob from
   the connector during `connect()`. On DP-2 with the glasses
   attached, an I2C bus contention or slow EDID read could block
   long enough for the watchdog to fire.
2. **Kernel-level ioctl contention** — Hyprland and monado both hold
   handles on `/dev/dri/card1`. The lease ioctls monado is firing
   in parallel with this `connect()` could serialize behind one
   another in the kernel and stall both.

Either is consistent with the log cutoff happening mid mode-iteration
without an error return. Confirming would need an strace or
`perf trace` of Hyprland against the DRM fd during a reproduction.

## How to apply

When a "Hyprland safe-mode again" report comes in:

1. Find the dead log session signature (`/run/user/1000/hypr/<sig>_*/hyprland.log`)
   and check **what was happening at crash time**, not at session
   start. Compare to `coredumpctl` timestamps.
2. Check whether external was plugged AT crash time (`grep -n
   'HDMI-A-1' hyprland.log` and look for `disconnected`/`connected`
   states near the SIGABRT timestamp). If unplugged → not CDCLK; this
   file applies.
3. Sum active outputs' pixel rates (W × H × refresh) at crash time.
   Under ~1 GP/s → not CDCLK; this file applies.
4. Look for a `Connecting connector DP-2` line near the end of the
   log. If the log cuts off in the middle of mode-iteration, this is
   the lease-hotplug stall mode.
5. Cite specific log line numbers and the session signature in any
   writeup. Do NOT auto-attribute to CDCLK because we have one
   reproducible CDCLK case on file.

## References

- `/run/user/1000/hypr/521ece...1778072203_*/hyprland.log:16182-16216`
  — crash region with the mode-iteration cutoff
- `/run/user/1000/hypr/521ece...1778072203_*/hyprland.log:9415` — HDMI
  unplug event (proves CDCLK-overrun is not active at crash time)
- `/run/user/1000/hypr/521ece...1778072203_*/hyprland.log:5411-5585`
  — earlier in the same session, CDCLK page-flip-awaiting loop while
  external was plugged (separate failure, distinct mechanism)
- `/run/user/1000/hypr/521ece...1778072203_*/hyprland.log:1984, 2549,
  3041` — `drm: Non-desktop connector` (rules out non_desktop
  hypothesis)
- `/run/user/1000/hypr/521ece...1778072203_*/hyprland.log:2580-2583`
  — wp-drm-lease grant to monado (lessee id 2)
- `.research/src/aquamarine/src/backend/drm/DRM.cpp:1646` —
  `SDRMConnector::connect()` entry point
- `.research/src/aquamarine/src/backend/drm/DRM.cpp:1726` —
  `getDRMPropBlob(...edid...)` candidate stall site
- `memory/xr-hyprland-cdclk-cap.md` — companion file for the OTHER
  safe-mode mode (real, reproducible, mitigated by `1f84b02`)
