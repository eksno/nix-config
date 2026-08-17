---
type: project
title: EDID override — non-desktop bit + 3840x1080 SBS mode injection
created: 2026-05-06
---

The `system/lib/xr/glasses-edid/` module makes Linux see the Rayneo
glasses as a non-desktop output (so wlroots advertises the connector
via `wp-drm-lease-v1`) AND exposes the 3840x1080@60 native SBS mode the
glasses' panel actually drives in 3D mode. See
[wlroots leasing rules](xr-wlroots-leasing-rules.md) for the lease half.

## Pieces

- **Original EDID**: `xr/edid/glasses-original.bin` (256 bytes captured
  from `/sys/class/drm/card1-DP-2/edid`).
- **Patcher**: `xr/edid/patch_glasses_edid.py`. Three modifications:
  1. Inserts a Microsoft HMD Vendor-Specific Data Block (OUI
     `0x5C 0x12 0xCA`, 21-byte payload, version `0x02`) into the
     CTA-861 extension. Kernel sets `non_desktop=1` on the connector.
  2. Replaces base EDID DTD 1 with a synthesized 3840x1080@60 mode
     (297 MHz pixel clock, derived by doubling the original
     1920x1080@60's H values). monado's `choose_best_vk_mode_auto`
     picks this (highest pixel count) and the SBS surface lands at
     native size.
  3. Bumps the Display Range Limits descriptor's max-dotclock cap
     from 160 → 300 MHz so kernels that validate added modes against
     the cap accept the 297 MHz mode.
- **Patched EDID**: `xr/edid/glasses-nondesktop.bin`. Verified with
  `edid-decode`. THIS is what gets shipped.
- **Module**: `system/lib/xr/glasses-edid/default.nix` installs the patched
  EDID via `hardware.firmware`, sets
  `boot.kernelParams = [ "drm.edid_firmware=DP-2:edid/rayneo-air4pro-glasses.bin" ]`,
  and adds the USB ACL udev rule (see [Rayneo hardware facts](xr-rayneo-hardware.md)).

## How to regenerate the patched EDID

If the glasses change EDID (firmware update, new model), or another host
uses a different connector:

```bash
# 1. Capture
cat /sys/class/drm/card1-DP-2/edid > xr/edid/glasses-original.bin

# 2. Patch
python3 xr/edid/patch_glasses_edid.py \
  xr/edid/glasses-original.bin \
  xr/edid/glasses-nondesktop.bin

# 3. Verify
edid-decode xr/edid/glasses-nondesktop.bin | grep -i "vendor-specific"
# Want: "Vendor-Specific Data Block (Microsoft), OUI CA-12-5C, Version: 2"

# 4. Rebuild + reboot (kernel reads firmware EDID at boot only)
./update.sh && systemctl reboot
```

## Per-host caveat

The connector name is hardcoded in the module
(`drm.edid_firmware=DP-2:...`). On a different host the glasses may come
up at DP-1, DP-3, or HDMI-A-2. Check `/sys/class/drm/card*-*` after
plugging. The module currently only imports for `lewis`
(`system/hosts/lewis/default.nix`). To extend to another host, copy the
module and adjust the connector name.

## Rollback

If a glasses firmware change breaks parsing, or the override needs to
come off temporarily (e.g. to use the glasses as a regular external
monitor — niche), remove the import line from
`system/hosts/lewis/default.nix`, rebuild, reboot. The kernel param
disappears in the next boot generation.

If the rebuild itself fails to boot, select the previous generation
from systemd-boot.
