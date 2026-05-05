---
type: project
title: Mesa anv display-plane gap on Intel Arc (the wall)
created: 2026-05-06
---

**TL;DR:** Mesa's `anv` Vulkan driver on Intel Arc (lewis) advertises
`VK_KHR_display` and `VK_EXT_acquire_drm_display` at the *instance* level
but does NOT implement the device-level functions. Any direct-mode VR path
on lewis hits this. Until upstream Mesa wires the missing functions, no
amount of monado/wayvr/EDID/lease config will produce visual output on
the glasses via the direct-render path.

## Symptom

monado succeeds at:
- Vulkan instance creation with display extensions
- `vkAcquireDrmDisplayEXT` on the leased connector
- `vkCreateDisplayPlaneSurfaceKHR`
- swapchain creation

Then fails immediately at first `vkQueuePresentKHR` with
`VK_ERROR_SURFACE_LOST_KHR`. Glasses stay black.

## How to verify it's still the wall (do this before assuming it's fixed)

```bash
# 1. Check vulkaninfo for the warning
vulkaninfo 2>&1 | grep -i "displayplaneproperties"
# Expect: "ICD for selected physical device does not export
#          vkGetPhysicalDeviceDisplayPlanePropertiesKHR"

# 2. Reproduce independently of monado
nix-shell -p vulkan-tools --run 'vkcube --wsi display'
# Expect: "Cannot find any display!" on both Intel Arc and llvmpipe
# If this works, Mesa has been fixed — re-test the XR path.
```

## What this rules out

Don't propose any of these on lewis without first re-running the vkcube
check. They will all fail with the same root cause:

- "Just take the lease earlier in the launcher"
- "Use a different OpenXR runtime that does direct mode"
  (most go through Mesa WSI too)
- "Tweak monado's compositor backend selection"
- "Adjust EDID modes / refresh / colorspace"

## Forward options (none cheap)

1. **Patch Mesa anv** to implement display plane funcs — large upstream
   work. Out of scope for breezy-hyprland.
2. **Stay in Wayland-windowed mode** — bypasses the gap entirely but needs
   the SBS rendering problem from Phase 2 solved (custom 3840x1080 mode,
   HID 3D-mode toggle).
3. **Different GPU** — n/a for lewis.
4. **Different OpenXR runtime that uses GBM/KMS directly** instead of
   Vulkan WSI — investigate, may not exist for OSS stack.

## Sources

- vulkaninfo + vkcube reproduced 2026-05-06 on lewis
- monado source uses `vk_swapchain_present` → standard Vulkan WSI
- LEARNINGS.md "VkDisplaySurfaceKHR fails on wlroots-leased connector"
- Mesa source: `src/intel/vulkan/anv_*` does not implement
  `vkGetPhysicalDeviceDisplayPlanePropertiesKHR` (verified)
