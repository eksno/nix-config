---
type: feedback
title: XR loop history — incidents where I went in circles
created: 2026-05-06
---

Concrete log of times in the xr/ workstream where I (Claude) wasted
multiple attempts on the same wrong hypothesis. Each entry: what I tried
repeatedly, what the actual root cause was, what evidence would have
told me sooner. **Read before starting any xr/ debugging session.**

## Loop 1: "Disable the Hyprland monitor to free the connector for monado"

**Wrong hypothesis**: If Hyprland is using DP-2, monado can't lease it.
So `hyprctl keyword monitor "desc:..., disable"` before monado, restore
after.

**Attempts**: Two full launcher iterations, ~3 reboot cycles, debug
logs read.

**Actual root cause**: wlroots only advertises EDID-non-desktop
connectors via `wp-drm-lease-v1` regardless of whether they're
"disabled." Disabling the monitor in Hyprland removed the only
fallback path (Wayland-windowed mode), making things strictly worse —
monado exited 2s after Vulkan init.

**Evidence I should have looked for first**:
- wlroots source: `wlr_drm_lease_v1.c` filters on `connector->non_desktop`
- Read upstream Hyprland issues / matrix discussions for "lease"
  before assuming compositor-level config could solve it

**Fix path**: EDID override (kernel-level non_desktop=1).

**Captured in**: [wlroots leasing rules](xr-wlroots-leasing-rules.md)

## Loop 2: "Visual is black — must be a config knob somewhere"

**Wrong hypothesis**: Once monado takes the lease and OpenXR reaches
FOCUSED, the only reason for a black panel must be misconfigured
modes, stride, refresh, or colorspace.

**Attempts**: Multiple launcher tweaks, EDID DTD inspections, monado
log re-reads. Considered re-patching EDID with different mode hints.

**Actual root cause**: Mesa anv on Intel Arc doesn't implement
`VK_KHR_display` device-level functions. monado's
`vkAcquireDrmDisplayEXT` succeeds, surface creates, swapchain creates,
then first present fails with `VK_ERROR_SURFACE_LOST_KHR`. Pure Mesa
gap, not a config issue.

**Evidence I should have looked for first**:
- `vulkaninfo 2>&1 | grep -i displayplane` would have shown the warning
- `vkcube --wsi display` reproduces the failure with no XR involvement
- Should have isolated Vulkan-display-from-leased-FD in a 30-line C
  reproducer or off-the-shelf tool BEFORE blaming monado/EDID

**Fix path**: None at this layer. See
[Mesa anv display gap](xr-mesa-anv-display-gap.md) for forward options.

## How to use this file

Before starting a new debugging session in xr/:

1. Read the entries above
2. Check whether your current hypothesis is structurally similar to one
   of the failed ones (e.g. "tweak compositor config to expose the
   connector" — that's loop 1)
3. If similar: stop. Re-derive evidence from scratch before proceeding.

When a new loop happens (3+ attempts on same hypothesis with no
progress): add a new entry here BEFORE moving on. The act of writing
the entry forces structuring the actual root cause.
