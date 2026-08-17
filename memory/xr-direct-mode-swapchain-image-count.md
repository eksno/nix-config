---
type: project
title: Monado direct-mode needs 3 swapchain images on Mesa anv
created: 2026-08-16
---

Monado's `comp_target_swapchain.c` deliberately picks **2** swapchain
images for direct-mode targets, to run "lockstep with the display". The
comment says this works on AMD(Mesa) and Nvidia(Blob), and it assumes
`vkQueuePresentKHR` returns once the page flip is *queued*.

On Mesa **anv**'s `wsi_display` it returns once the flip has *scanned
out*. Rendering then serialises behind scanout and the headset presents
at exactly half rate.

**Signature to recognise it:** monado logs `Compositor probably missed
frame by 16.7ms` at a steady 30/s, and the miss is always ~one full
frame period — never a variable overrun. A load-related bottleneck gives
scattered numbers; this one is bit-identical run to run (601 per 20 s,
twice, across an unrelated capture fix). **Identical counts across a
change means the change wasn't the bottleneck — look one layer down.**

**Fix:** `XRT_COMPOSITOR_PREFERRED_IMAGE_COUNT=3`. No patch needed;
`caps.maxImageCount` is 0 (unlimited) so 3 is accepted. Applied durably
as a `--set-default` wrapper on `monado-service` in
`system/lib/xr/monado-rayneo/package.nix`. Result: 0 missed frames,
60.7 fps.

Related: [[xr-mesa-anv-ebusy-on-first-present]] — the other anv
`wsi_display` divergence on this stack.
