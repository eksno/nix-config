---
type: reference
title: XR debug command cheatsheet
created: 2026-05-06
---

One-liners for the recurring "is X working" checks. All assume host
`lewis` user `jorge` with the current xr/ stack deployed.

## Hardware presence

```bash
lsusb -d 1bbb:af50                           # USB enumeration
ls /sys/class/drm/ | grep -i dp              # DRM connectors
cat /sys/class/drm/card1-DP-2/status         # connected | disconnected
cat /sys/class/drm/card1-DP-2/edid | wc -c   # 256 = base+1 ext, 0 = no EDID
```

## EDID override health

```bash
# Did the kernel substitute the firmware EDID?
diff <(cat /sys/class/drm/card1-DP-2/edid) \
     /home/jorge/nix-config/xr/edid/glasses-nondesktop.bin
# Silent = good

# Non-desktop bit set?
cat /sys/class/drm/card1-DP-2/non_desktop    # want: 1

# Decode whatever the kernel has now
edid-decode /sys/class/drm/card1-DP-2/edid | grep -i "vendor-specific"
# want: "Vendor-Specific Data Block (Microsoft), OUI CA-12-5C, Version: 2"

# Kernel cmdline includes the param?
cat /proc/cmdline | grep edid_firmware
```

## Hyprland's view

```bash
hyprctl monitors                              # active outputs
hyprctl monitors all                          # includes disabled/non-desktop
hyprctl monitors all | grep -i smart          # SmartGlasses presence
```

## Vulkan / Mesa display-mode check

```bash
vulkaninfo 2>&1 | grep -i "displayplaneproperties"
# Bad: "ICD ... does not export vkGetPhysicalDeviceDisplayPlanePropertiesKHR"
# Means Mesa anv is still missing display plane support (the wall)

nix-shell -p vulkan-tools --run 'vkcube --wsi display'
# Bad: "Cannot find any display!"
# Means Mesa display WSI is broken
```

## Monado runtime

```bash
# Live log while running breezy-hyprland
tail -F /run/user/$(id -u)/monado-service.log

# Did monado get a lease?
grep -i "drm lease\|leased\|direct mode" /run/user/$(id -u)/monado-service.log

# OpenXR runtime resolution
echo "$XR_RUNTIME_JSON"
```

## drm_info (rich connector info)

```bash
nix-shell -p drm_info --run 'drm_info /dev/dri/card1' | less
# Look for: connector DP-2, properties: "non-desktop", CRTC, current mode
```

## Quick "is it the cable" probe

If `/sys/class/drm/card1-DP-2/` doesn't exist but `lsusb` shows the
glasses, the cable is power-only USB. See
[Rayneo hardware facts](xr-rayneo-hardware.md).
