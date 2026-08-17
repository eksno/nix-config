---
type: project
title: Rayneo Air 4 Pro hardware facts
created: 2026-05-06
---

Concrete identifiers and gotchas for the AR glasses Jorge owns.

## IDs and connector

- USB: vendor `1bbb` product `af50` (`lsusb -d 1bbb:af50` to confirm)
- USB-C cable carries DP alt-mode + USB 2 (HID for IMU/control)
- On host `lewis`: comes up as DRM connector **DP-2**
  (`/sys/class/drm/card1-DP-2/`). This is per-host — different laptops'
  DP alt-mode connector paths differ. Verify before reusing the EDID
  override on another box.
- EDID identifies as "Technical Concepts Ltd SmartGlasses" — useful for
  Hyprland `desc:` matchers when needed.
- Native panel mode is per-eye; SBS-packed display surface is 3840x1080.

## Cable quality matters

A power-only USB-C cable enumerates the device as **HID-only** with NO
DP alt-mode. The IMU works (mouse mode functions) but the glasses do not
appear as a DRM connector and no XR rendering is possible. If the
glasses-edid module's verification commands return "no such file" for
`/sys/class/drm/card1-DP-2/`, suspect the cable first.

## USB ACL boot-race (FIXED, but understand why)

Upstream `xr-linux-driver` ships a udev rule with `TAG+="uaccess"` for
per-session ACLs. systemd-logind only applies that tag if it's already
running when the device enumerates. At boot, the device enumerates
*before* logind starts, so the ACL never applies. Symptom:
`monado-rayneo` fails with "Failed to open USB device" 30 retries until
the user physically replugs.

**Fix lives in** `system/lib/xr/glasses-edid/default.nix`: an extra udev
rule sets `MODE="0660", GROUP="users"` for `1bbb:af50`. This is
group-permission based and survives the boot-race. Kept at 0660 (not
0666) so non-`users` accounts can't open the headset.

## Display modes the panel actually accepts

**Stock EDID** advertises only **1920x1080** modes (multiple DTDs at 60
and 120 Hz, all 1920x1080). There is no 3840x1080 mode. The kernel
without an EDID override only programs a 1920-wide DP signal.

**Patched EDID** (deployed on lewis as of commit `7122089`) injects a
3840x1080@60 DTD into the patched EDID by replacing base DTD #1, and
bumps the Display Range Limits max-dotclock from 160 to 300 MHz so the
mode is accepted. monado then picks 3840x1080 as the highest-pixel
mode and renders SBS at native (1920 per eye). See
`xr-edid-override.md` and `xr/edid/patch_glasses_edid.py` for the
generation pipeline.

The glasses have an internal "3D vs 2D" mode (HID-toggled, see below).
In 3D mode they treat the incoming 3840x1080 host signal as **side-by-side
packed** — each eye gets the left-half / right-half (1920x1080 per
eye). In 2D mode they show the same image to both eyes.

Known regression to watch: after reboot with the 3840x1080 EDID,
Hyprland intermittently crashes into safe-mode during lease cycles.
Aquamarine logs show `drm: Cannot commit when a page-flip is awaiting`.
Suspected CDCLK contention from the new mode — open issue.

## HID toggle: 2D vs 3D mode (xr-driver SDK + control IPC)

The closed-source `libRayNeoXRMiniSDK.so` exposes
`ffalcon::XRMiniService::SwitchTo2D()` and `SwitchTo3D()`. xr-driver
calls these via its plugin glue and surfaces a runtime control through
`/dev/shm/xr_driver_control`:

```
printf 'sbs_mode=enable\n'  > /dev/shm/xr_driver_control   # 3D mode
printf 'sbs_mode=disable\n' > /dev/shm/xr_driver_control   # 2D mode
```

(Other valid values rejected: `false`/`true`, `0`/`1`, `disabled`,
`enabled`, `stretched`. **The exact string is `enable` / `disable`.**
The driver logs `Invalid sbs_mode value: %s` for anything else.)

Confirm via `cat /dev/shm/xr_driver_state | grep sbs_mode_enabled`.

xr-driver must be running for these to take effect — `breezy-hyprland`
stops xr-driver, so toggle BEFORE launching it.

When stopped, xr-driver does NOT toggle the glasses back to 2D — they
stay in whatever mode was last set. Default startup behavior with
`external_mode=breezy_desktop` is to enable SBS.

## Common enemy of past sessions

- "It worked yesterday" → check the cable
- "It worked yesterday" → check `lsusb` — was there a kernel update that
  bumped the connector path from card1 to card0 or DP-2 to DP-3?
- Glasses left off for hours → may need a single reconnect to recover
  link training, not a config issue
