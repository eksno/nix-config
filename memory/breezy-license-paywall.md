---
type: project
title: Breezy productivity-tier paywall — why the GNOME path was abandoned
created: 2026-05-06
---

Context for any future "let's just use breezy-gnome / xr-driver
breezy-mode" suggestion. The short answer is: the upstream
xr-linux-driver gates breezy-mode behind a license check, and Jorge's
constraint is "no paying."

## What the gate does

`xr-linux-driver` writes head-pose data to `/dev/shm/breezy_desktop_imu`
**only when both**:

1. `output_mode=external_only` AND `external_mode=breezy_desktop` are set
2. `is_productivity_granted()` returns true (license check)

Without the granted flag, the SHM file stays empty even when the rest of
the config is correct. The breezy-gnome GNOME extension reads from that
SHM and renders nothing if it's empty.

## What "no paying" rules out

- breezy-gnome with active world-lock / multi-screen
- breezy-mode in xr-driver
- Any path that depends on `is_productivity_granted()` returning true

## What's still useful (kept installed)

- `xr-driver` for **mouse mode** (not breezy mode) — works without
  license. Useful as an IMU debug tool.
- `breezy-gnome` package — built into the system, gated at runtime. Stays
  for the day someone might pay for productivity tier.
- `breezy-session` — registers a GNOME session via SDDM as a fallback.
  Currently unused.
- `breezy-recenter` — works from any compositor with control of
  `/dev/shm/xr_driver_control`.

## The open-source path (what we're actually doing)

Monado + WayVR + glasses-edid (Phase 3 architecture). This is the
non-paywalled replacement. See [XR stack overview](xr-stack-overview.md).

## Don't propose

- "Just enable breezy mode" → license-gated
- "Patch xr-linux-driver to bypass the check" → forking upstream is more
  invasive than the OSS path; not what Jorge wants
- "Use breezy-gnome on top of monado" → architectural mismatch; breezy
  expects the IMU SHM, monado provides OpenXR
