---
type: project
title: wayvr GPU/DMA-BUF capture segfault on Mesa anv (pending hypothesis)
created: 2026-05-06
---

`wayvr --openxr --show` segfaults reproducibly on `lewis` (Mesa anv
26.0.6 + Hyprland 0.54.3 + wayvr 26.2.1) right after the OpenXR
session reaches FOCUSED. The crash sits between the "Using GPU
capture" warning and the first capture frame, in the
DMA-BUF-import-into-Vulkan path.

## Crash signature

Last log lines in `.scratch/diagnose-surface-lost/breezy-stdout-v3.txt`:

```
INFO  wayvr::backend::openxr: entered state FOCUSED
WARN  wayvr::overlays::screen::backend: Using GPU capture. ...
        switch 'Wayland capture method' to a CPU option!
   at wayvr/src/overlays/screen/backend.rs:200
breezy-hyprland: line 99: 267806 Segmentation fault (core dumped)
                                  wayvr --openxr --show
```

Then `wayvr` is gone. Reproduces every time across both v3 (compute
monado) and v4 (graphics monado) runs; the monado side is irrelevant
to whether wayvr crashes.

## Suspected mechanism

`backend.rs:197-217` is the DMA-BUF capture branch:

1. `MyFirstDmaExporter::new(app.gfx.clone(),
   app.gfx_extras.drm_formats.clone())` builds the exporter.
2. `self.capture.init(dmabuf_formats, user_data, receive_callback)`
   wires `wlr_screencopy_v1` to it and calls
   `request_new_frame()`.
3. wayvr captures eDP-1 + HDMI-A-1, gets DMA-BUFs back from the
   compositor, then asks vulkano to import them.

Hypothesis: vulkano's DMA-BUF import path on Mesa anv hits a modifier
mismatch (Hyprland may export a tiled modifier wayvr's import code
doesn't handle, or the format/modifier negotiation is asymmetric for
multi-output capture). The crash is in unsafe FFI / Vulkan land, so
the panic prints nothing structured — just a raw segfault.

## Workaround attempts

- **Atlas-grow patch (`b02dffa`, "wayvr-anv" overlay) — RULED OUT.**
  The patch raises wgui's initial text atlas from 256 → 2048 to skip
  the racy `text_atlas::grow()` path. It works (post-patch v3 log
  shows NO `Grow Color atlas` line) but wayvr still segfaults at the
  same place. Atlas-grow was just the previous log line in v4, not
  the previous function call. The "wayvr-anv" override and the
  patch can stay (cheap, harmless, and may still avoid a real future
  race) but they do not unblock the capture crash.

## What to try next

1. **Force CPU capture.** The warning literally says: "go to the
   Dashboard's Settings tab and switch 'Wayland capture method' to
   a CPU option." We can't reach the dashboard yet (it's the thing
   that crashed), so look for a config file or env var override —
   grep wayvr's source for `capture_method` / `Wayland capture
   method`, and check `~/.config/wlxoverlay/`-style state files
   for the persisted setting.
2. **Capture a backtrace.** `RUST_BACKTRACE=full` only helps for
   panics, not native segfaults. Run wayvr under `gdb --args` or
   collect the core dump (`coredumpctl info wayvr`) to confirm the
   crash is in vulkano's DMA-BUF import and identify which call.
3. **Patch wayvr / vulkano DMA-BUF import** to handle anv's
   modifiers — only worth doing once the backtrace pins the exact
   call site.
4. **Single-output capture.** lewis has eDP-1 + HDMI-A-1 + the
   leased DP-2; if multi-output triggers the modifier mismatch,
   limiting wayvr to one screen may sidestep it.

## Why

Without this writeup, future agents seeing the segfault are likely
to (a) re-blame the swapchain-usage path in monado (which is now
fixed and verified), or (b) re-blame the atlas-grow code path
(which was already worked around and is no longer in the post-patch
log). The actual surface area is the wlr_screencopy_v1 → DMA-BUF →
vulkano-import chain inside wayvr.

## How to apply

Before debugging the wayvr crash again:

1. Re-read this file and `xr-mesa-anv-display-gap.md`.
2. Confirm the latest run still segfaults at
   `wayvr/src/overlays/screen/backend.rs:200` — if the log line
   moves, the failure mode has shifted and this file is stale.
3. Pick the cheapest unexplored option from "What to try next" —
   probably (1) finding the CPU-capture override, since the
   upstream warning explicitly suggests it.
4. Do NOT waste cycles re-patching atlas-grow or the monado
   swapchain — both are already addressed.

## References

- `system/lib/xr/wayvr-anv/` — current wayvr override (atlas-grow
  workaround + pname preserved so vendor-staging hits cache)
- `.research/src/wlx-overlay-s/wayvr/src/overlays/screen/backend.rs`
  — local source for grepping the capture path
- `.scratch/diagnose-surface-lost/breezy-stdout-v3.txt` — latest
  reproducer log
- `memory/xr-mesa-anv-display-gap.md` — companion file; describes
  why the monado side is now clean
