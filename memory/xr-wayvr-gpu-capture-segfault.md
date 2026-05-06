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

- **CPU-capture override (`capture_method: screencopy`) — RULED OUT.**
  Round 2 finding (2026-05-06): dropped a `~/.config/wayvr/config.yaml`
  with `capture_method: screencopy` (out-of-tree, NOT in dotfiles —
  see `xr/STATE.md` TODO to codify). Confirmed picked up by wayvr:
  log shows `Not using DMA-buf capture due to ScreenCopyCpu` followed
  by `Software capture will take place on the main thread`. The
  segfault then recurs **one log line later**, at the same wall-clock
  distance from FOCUSED, with no DMA-BUF import in the call path.
  So DMA-BUF import was *also* a coincident log line, not the cause.
  The actual crash is in capture-init / post-capture-method-decision
  region — possibly Vulkan queue-family setup, vulkano-anv interaction,
  or something deeper in the screencopy CPU path. NOT in the DMA-BUF
  import path.

## What to try next

DMA-BUF avoidance is exhausted. The crash sits in the
post-method-decision / capture-init region regardless of GPU vs CPU
capture choice. Remaining options:

1. **Capture a backtrace — top priority now.** `RUST_BACKTRACE=full`
   only helps for panics, not native segfaults. Run wayvr under
   `gdb --args` or collect the core dump (`coredumpctl info wayvr`)
   to identify the actual crashing frame. Without this, every
   "blame the last log line" attribution will keep being wrong
   (see LEARNINGS.md "Coincident log line ≠ root cause, second time").
2. **Bisect with debug builds.** Build wayvr / vulkano with debug
   symbols (or `RUSTFLAGS=-g`) and step through the capture init
   path post-method-selection. Look at queue-family selection,
   any Vulkan device creation that happens after the capture method
   is chosen, and the first frame request.
3. **Single-output capture.** lewis has eDP-1 + HDMI-A-1 + the
   leased DP-2; if multi-output is part of the trigger, limiting
   wayvr to one screen may sidestep it. Cheap to try via wayvr config.
4. **Try a different vulkano version or pin.** If the bug is in a
   specific vulkano release's interaction with anv, bisecting
   vulkano (or comparing to a slightly older wayvr that pinned a
   different vulkano) may localize it.

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
