---
type: project
title: wlroots only leases EDID-non-desktop connectors
created: 2026-05-06
---

wlroots (the library Hyprland uses) advertises a connector via the
`wp-drm-lease-v1` Wayland protocol **only if** the connector's EDID has
the non-desktop bit set. There is no runtime API to override this and no
Hyprland config that flips it. The bit must be in the EDID at probe time.

## What does NOT work (don't retry these)

- `hyprctl keyword monitor "desc:..., disable"` before launching monado.
  Tested 2026-05-06 — strictly worse than nothing. Connector goes
  `disabled: true` in `hyprctl monitors all` but is still NOT advertised
  for lease. monado then fails to bind Wayland-windowed fallback (output
  is gone) and exits ~2s after Vulkan init.
- Any `monitor =` config in Hyprland — affects what Hyprland *uses*,
  not what wlroots *advertises for lease*.
- Userspace "claim" tools — there's no equivalent of `xset` for this.

## What works

EDID override at the kernel level via `drm.edid_firmware=`. The kernel
parses the (patched) EDID, sets `connector.non_desktop = true`, and
wlroots picks it up at probe time.

The kernel only flips non_desktop=true if it sees a Microsoft HMD
Vendor-Specific Data Block in the CTA-861 extension (OUI `0x5C 0x12 0xCA`,
21-byte payload, version `0x02`). See
`drivers/gpu/drm/drm_edid.c::cea_db_is_microsoft_vsdb`.

For the implementation see [EDID override module](xr-edid-override.md).

## Verification chain

```bash
# 1. EDID was substituted by drm.edid_firmware=
diff <(cat /sys/class/drm/card1-DP-2/edid) \
     /home/jorge/nix-config/xr/edid/glasses-nondesktop.bin
# Should be silent

# 2. Kernel parsed the VSDB
cat /sys/class/drm/card1-DP-2/non_desktop
# Should print 1

# 3. Hyprland skips it for desktop use
hyprctl monitors | grep SmartGlasses
# Should be empty (Hyprland intentionally skips non-desktop outputs)

# 4. wlroots advertises for lease — only fully testable by running
#    monado-service and checking its log:
grep -i "drm lease" /run/user/1000/monado-service.log
# Want: "Selected DRM lease device" + a real connector path
# Bad:  "Found no connectors available for direct mode"
```
