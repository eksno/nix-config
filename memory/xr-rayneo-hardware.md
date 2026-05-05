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

## Common enemy of past sessions

- "It worked yesterday" → check the cable
- "It worked yesterday" → check `lsusb` — was there a kernel update that
  bumped the connector path from card1 to card0 or DP-2 to DP-3?
- Glasses left off for hours → may need a single reconnect to recover
  link training, not a config issue
