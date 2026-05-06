---
type: project
title: Hyprland safe-mode crash from CDCLK budget overrun on lewis (lease-time)
created: 2026-05-06
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
