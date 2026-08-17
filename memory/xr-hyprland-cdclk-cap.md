---
type: project
title: Hyprland safe-mode crash from CDCLK budget overrun on lewis (lease-time)
created: 2026-05-06
updated: 2026-05-06
---

When `wp_drm_lease_v1` hands DP-2 to monado at 3840x1080@60 (the
glasses' SBS native mode after the EDID injection in commit
`7122089`), Hyprland reconfigures the rest of its outputs simultaneously
per `dotfiles/default/hypr/users/jorge/default/monitor.conf`. If the
combined active-output pixel bandwidth exceeds the Intel display
engine's CDCLK budget, the modeset fails atomic-commit, aquamarine
loops on `drm: Cannot commit when a page-flip is awaiting`, and
Hyprland's watchdog eventually kills the session into safe-mode.

This is what was happening on lewis. With:

- eDP-1 @ 1920x1080@120
- HDMI-A-1 @ 1920x1080@119.98
- DP-2 (leased) @ 3840x1080@60

the combined pixel bandwidth was ~1.12 GP/s, over the lewis hardware's
~1.0 GP/s tolerance. Smoking gun in the Hyprland log:

`/run/user/1000/hypr/521ece...1778064687_*/hyprland.log` lines 511-513
showing the page-flip-awaiting loop right after the lease event.

## Workaround applied (commit `1f84b02`)

`dotfiles/default/hypr/users/jorge/default/monitor.conf:14` —
HDMI-A-1 capped from 119.98Hz to 60Hz:

  monitor = HDMI-A-1, 1920x1080@60.00, ..., 1

Total bandwidth drops to ~995 MP/s, under the threshold. Lease event
no longer triggers the page-flip-awaiting loop in the captured run.

## Open issue (NOT yet diagnosed)

Even with the cap, **Hyprland is still ending up in safe-mode on
plain login** after the recent debugging round. Possible causes
(none verified):

1. Previous crashes left state on disk that Hyprland auto-recovers
   from with safe-mode on the next launch.
2. The `@60.00` mode string in `monitor.conf` doesn't exactly match
   what HDMI-A-1's EDID exposes (different rounded refresh rate
   than expected), so Hyprland falls back to safe-mode parsing.
3. There's another CDCLK pathology in the eDP-1 + HDMI-A-1 + leased
   DP-2 combo that the cap didn't address.

Triage starts by `grep -i 'safe' /run/user/1000/hypr/*/hyprland.log`
on the next failing instance to read the actual safe-mode trigger,
then `hyprctl monitors all` to see what mode HDMI-A-1 actually got.

## CDCLK is not the only safe-mode trigger (2026-05-06 round 2)

A second wayvr run on 2026-05-06 at 22:41:01 crashed Hyprland into
safe-mode at 22:41:09 (8 seconds in). Hyprland SIGABRT'd via watchdog,
coredump captured. **CDCLK was not the cause this time:**

- HDMI-A-1 was disconnected at crash time (dead log
  `/run/user/1000/hypr/521ece...1778072203_*/hyprland.log` lines
  9415 onward show external unplugged). With only eDP-1@2880x1800x120
  + leased DP-2@3840x1080x60 active, total bandwidth was ~870 MP/s,
  well under the ~1 GP/s ceiling.
- No `Cannot commit when a page-flip is awaiting` log near the crash.

Mechanism per the dead log lines 16182-16216: Hyprland was inside
aquamarine's `SDRMConnector::connect()`
(`.research/src/aquamarine/src/backend/drm/DRM.cpp:1646`) iterating
connector modes when the event loop stalled; watchdog SIGABRT'd
Hyprland after the 5-second threshold. The mode-iteration log
(`Mode 0... Mode 1...`) cuts off mid-list. That `connect()` is
internal aquamarine data-setup, NOT a kernel modeset, so the original
"modeset hang" framing was wrong too.

Leading hypothesis (NOT confirmed): the stall is during
`getDRMPropBlob(... props.values.edid ...)` at `DRM.cpp:1726` —
slow/blocked I2C EDID read on DP-2 — or kernel-level ioctl contention
with monado's concurrent lease operations on the same DRM fd.

**The `1f84b02` HDMI@60 cap remains correct for its purpose** (the
CDCLK-overrun page-flip-awaiting loop documented above is real and
reproducible per `lines 5411-5585` of the same dead log when external
was plugged earlier in the session). It does NOT prevent this distinct
second class of safe-mode crash. See companion file
`memory/xr-hyprland-lease-hotplug-stall.md` for full evidence and
triage notes for the new mode.

**Lesson:** when investigating a "Hyprland is in safe-mode again"
report, check the actual log signature at the *crash time* (not just
earlier in the session). CDCLK overrun and lease-hotplug stall are
two different failure modes with different fixes.

## Why

Without this writeup, the next time the safe-mode loop or
page-flip-awaiting log line shows up, the next agent will likely
re-blame the wp_drm_lease_v1 protocol, the EDID override, or
monado's swapchain code — all of which were already verified clean
in the round that produced this file. The actual surface area is
**Intel CDCLK budget vs sum of active-output pixel rates**, and the
lever is "lower a refresh rate or disable an output during XR
sessions."

## How to apply

When debugging Hyprland safe-mode or `Cannot commit when a page-flip
is awaiting` on lewis (or any Intel display-engine-constrained host)
during XR runs:

1. Grep the relevant `hyprland.log` for that exact aquamarine string
   AND for `MODESET` / `CDCLK` near a lease event timestamp. If
   the page-flip loop sits adjacent to a lease event, this writeup
   is the right pointer.
2. Sum active outputs' pixel rates (W × H × refresh, in MP/s) to
   estimate the total. ~1.0 GP/s is the lewis ceiling observed so far.
3. Lower one output's refresh (preferably an external one not in
   focus during XR), rebuild + `hyprctl reload`. Do NOT just
   `hyprctl keyword monitor ... disable` — see LEARNINGS.md "wlroots
   only advertises non-desktop outputs via wp-drm-lease-v1" and the
   monitor-disable dead-end.
4. Verify with another XR session run that the page-flip loop is
   gone. The capture log should show the lease event followed by
   normal page-flip events, not the awaiting-loop.

A real upstream fix would be Hyprland sequencing the lease handover
so other outputs are downgraded *before* the lease modeset, instead
of trying to apply both simultaneously.

## References

- `dotfiles/default/hypr/users/jorge/default/monitor.conf:14` —
  the HDMI-A-1 cap (commit `1f84b02`)
- `/run/user/1000/hypr/521ece...1778064687_*/hyprland.log:511-513`
  — original smoking-gun page-flip-awaiting loop
- `xr/LEARNINGS.md` "CDCLK budget on Intel display engines" —
  short companion entry
- `xr/STATE.md` lewis row — current open-issue status for the
  post-cap safe-mode regression
