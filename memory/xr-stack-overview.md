---
type: project
title: XR stack overview — packages, modules, data flow
created: 2026-05-06
---

Entry point for any XR-related work in this repo. The whole XR effort lives
under `xr/` (workbench: STATE.md, LEARNINGS.md, PLAN.md, plans/, edid/) and
`system/lib/xr/` (NixOS modules + packages). All currently active for host
`lewis` user `jorge`.

## Packages

- `system/lib/xr/monado-rayneo/` — Monado OpenXR runtime overridden with
  GitLab MR !2737 (Rayneo Air 4 Pro driver). Filters nixpkgs' stale
  `monado-cylinder-aspectRatio.patch` (already in MR, would apply-reversed).
  Stock nixpkgs Monado does NOT enumerate Rayneo (only matches XREAL VID).
- `system/lib/xr/breezy-hyprland/` — Launcher script + package. Orchestrates
  monado-service + wayvr lifecycle. Reaches OpenXR FOCUSED.
- `system/lib/xr/glasses-edid/` — Host module: installs patched EDID,
  sets `drm.edid_firmware=DP-2:edid/...`, fixes USB ACL boot-race.
  Hardcoded to `lewis` (DP-2 connector name).
- `system/lib/xr/xr-driver/` — wheaney/xr-linux-driver. Works for mouse
  mode; breezy mode gated by upstream paywall (see breezy-license-paywall).
- `system/lib/xr/breezy-gnome/` — built but unused (license-gated). Kept
  as fallback if anyone ever buys productivity tier.
- `system/lib/xr/breezy-session/` — registers GNOME session via SDDM as
  optional fallback. Currently unused for active workflow.
- `system/lib/xr/breezy-recenter/` — CLI tool, works from any compositor.

## Data flow (current Phase 3 architecture)

```
Rayneo glasses (USB 1bbb:af50, DP-2)
   ↓ (DP alt-mode → kernel sees as monitor with non_desktop=1 due to EDID override)
wlroots/Hyprland
   ↓ (advertises connector via wp-drm-lease-v1 because non_desktop)
monado-service (--slow-debug)
   ↓ (takes lease, opens Vulkan display surface — FAILS HERE: Mesa anv gap)
wayvr (OpenXR client)
   ↓ (renders desktop panels in 3D, head-locked via Rayneo IMU)
Glasses display (intended; currently black due to Mesa wall)
```

## Where work is tracked

- `xr/PLAN.md` — pointer to active plan
- `xr/plans/` — historical + active plan documents (numbered)
- `xr/STATE.md` — current snapshot (what works, what doesn't, what's next)
- `xr/LEARNINGS.md` — append-only knowledge log; technical findings
- `FIXES.md` (repo root) — incident log for fixes (not feature work)

## Cross-references

- Hard wall: see [Mesa anv display gap](xr-mesa-anv-display-gap.md)
- Lease prerequisites: see [wlroots leasing rules](xr-wlroots-leasing-rules.md)
- Hardware: see [Rayneo hardware facts](xr-rayneo-hardware.md)
- Launcher gotchas: see [Monado IPC quirks](xr-monado-ipc-quirks.md)
