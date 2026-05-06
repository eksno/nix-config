---
type: project
title: wayvr capture segfault — root cause located in upload_image memcpy
created: 2026-05-06
updated: 2026-05-06
---

`wayvr --openxr --show` segfaults reproducibly on `lewis` (Mesa anv
26.0.6 + Hyprland 0.54.3 + wayvr 26.2.1) right after the OpenXR
session reaches FOCUSED. Both prior hypotheses (atlas-grow,
DMA-BUF import) were red herrings. **Real crash location: the
`copy_from_slice` memcpy inside `WCommandBuffer::upload_image`,
called from `receive_callback` while uploading a captured frame
into a Vulkan staging buffer.**

## Crash signature (from coredump)

`coredumpctl info <pid>` on PID 414959 / 314209 (both wayvr SIGSEGVs
on 2026-05-06) gives:

```
#0  __memcpy_avx_unaligned_erms                              (libc.so.6)
#1  wgui::gfx::cmd::WCommandBuffer<CmdBufXfer>::upload_image (wayvr bin)
#2  wayvr::overlays::screen::capture::upload_image           (wayvr bin)
#3  wayvr::overlays::screen::capture::receive_callback       (wayvr bin)
#4  MainThreadWlxCapture::receive                             (wayvr bin)
#5  ScreenBackend::should_render                              (wayvr bin)
#6  wayvr::backend::openxr::openxr_run                        (wayvr bin)
```

Independent of which capture method (`Dmabuf` vs `screencopy` CPU)
was selected — the crash is downstream of the method choice, on the
upload-into-Vulkan-staging step.

## Mechanism

`.research/src/wlx-overlay-s/wgui/src/gfx/cmd.rs:108-141`
(`WCommandBuffer::upload_image`):

```rust
let buffer: Subbuffer<[u8]> = Buffer::new_slice(..., data.len() as DeviceSize)?;
buffer.write()?.copy_from_slice(data);   // <-- memcpy frame #1
```

The `data: &[u8]` slice is built one frame up in
`.research/src/wlx-overlay-s/wayvr/src/overlays/screen/capture.rs`
(`receive_callback`). Two paths construct it:

- **MemFd (lines 524-567):**
  ```rust
  let len = frame.plane.stride as usize * frame.format.height as usize;
  let map = unsafe { libc::mmap(ptr::null_mut(), len, PROT_READ, MAP_SHARED, fd, offset) } as *const u8;
  let data = unsafe { slice::from_raw_parts(map, len) };
  ```
  **No `MAP_FAILED` check.** If `mmap` fails (bad fd, bad offset,
  rejected length), `map == (void*)-1 == 0xFFFFFFFFFFFFFFFF`, the
  slice points at unmapped memory, and the first byte read by
  `copy_from_slice` segfaults. Matches our backtrace exactly.

- **MemPtr (lines 568-587):**
  ```rust
  let data = unsafe { slice::from_raw_parts(frame.ptr as *const u8, frame.size) };
  ```
  Direct trust of `frame.ptr`/`frame.size` from the wlx-capture
  crate. If those are garbage (zero ptr, oversized size, freed
  region), same segfault.

Either way the bug pattern is the same: an unchecked raw pointer
+ length pair handed to `copy_from_slice`.

## Leading hypothesis

When wayvr captures via screencopy CPU (forced via
`~/.config/wayvr/config.yaml: capture_method: screencopy`), the
wlr-screencopy-v1 protocol returns a wl_shm pool fd. wlx-capture
either (a) returns an invalid fd because the protocol negotiation
failed silently, (b) hands back the wrong stride/height pair so
`stride * height` exceeds the real shm pool size and `mmap` rejects
it, or (c) the lease handover to monado raced against shm pool
allocation and the fd was closed before wayvr got it.

Most likely: lease handover races shm pool allocation. Hyprland's
output lease to monado happens around the same wall-clock window as
wayvr's first screencopy frame request, and the screencopy buffer
is tied to the leased output's wl_output proxy.

## What to try next

1. **Quick win: re-run with `RUST_LOG=trace` and capture stderr.**
   wlx-capture / wayvr trace logs will print frame format, fd,
   stride, offset, len before the upload. If `len` looks insane
   (e.g. multi-MB) or fd looks like -1, mmap-failure hypothesis is
   confirmed without a code change.

2. **`LD_PRELOAD` mmap shim.** Wrap `libc::mmap`, log args + return,
   pass through. Zero rebuild, ~10 lines of C. Confirms whether
   `mmap` succeeded or returned `MAP_FAILED` right before the crash.

3. **Patch + rebuild wayvr.** Add `if map == libc::MAP_FAILED { ... }`
   in `receive_callback` MemFd branch and a similar null/zero check
   in MemPtr branch. Either logs a clear error and returns `None`
   (clean failure), or — if the data is actually valid but the
   format is wrong — surfaces the next problem cleanly. Cost: a
   wayvr rebuild (vendor cache should hit since pname unchanged).

4. **Disable HDMI-A-1 capture entirely.** lewis has 3 outputs;
   limiting wayvr to one or zero captured screens may sidestep
   the racing-init theory while we patch upstream.

5. **Try wlx-overlay-s upstream (not wayvr fork).** Decouples
   "is the capture path broken on this config" from "is wayvr
   specifically broken." If upstream segfaults too, file the bug
   against wlx-capture; if not, the wayvr fork added the bug.

## Workarounds already ruled out

- **Atlas-grow patch (`b02dffa`).** Removed log line, did not fix
  segfault. "Coincident log line, not last function call."
- **`capture_method: screencopy`.** Switched method but not the
  upload path. Crash is downstream of the method choice.

Both stay because they're cheap and harmless, but neither is the fix.

## Why

Future agents debugging this should not (a) re-blame the monado
swapchain (fixed), (b) re-blame atlas-grow (workaround in place,
crash unchanged), or (c) re-blame DMA-BUF import (replaced by
screencopy, crash unchanged). The real surface area is the
`copy_from_slice` in `WCommandBuffer::upload_image` and the raw
slice constructed in `receive_callback`.

## How to apply

Before debugging the wayvr crash again:

1. Re-read this file and `xr-mesa-anv-display-gap.md`.
2. If the next coredump backtrace differs from the one above
   (different top frames, different libraries), this file is stale
   — update it. If it matches, skip ahead to "What to try next".
3. Cheapest unblocker is option 1 (RUST_LOG=trace) — it costs one
   wayvr run, no rebuild.
4. Do NOT waste cycles re-patching atlas-grow, the monado
   swapchain, or DMA-BUF import. All three are addressed.

## References

- `.research/src/wlx-overlay-s/wgui/src/gfx/cmd.rs:108` — crashing
  function
- `.research/src/wlx-overlay-s/wayvr/src/overlays/screen/capture.rs:470`
  — `upload_image` wrapper
- `.research/src/wlx-overlay-s/wayvr/src/overlays/screen/capture.rs:524`
  — MemFd path with the unchecked `mmap`
- `.research/src/wlx-overlay-s/wayvr/src/overlays/screen/capture.rs:568`
  — MemPtr path with raw `frame.ptr` trust
- `system/lib/xr/wayvr-anv/` — wayvr override; would receive any
  patch
- `coredumpctl list wayvr` — both 2026-05-06 cores still on disk;
  `coredumpctl debug <pid>` to re-inspect
- `memory/xr-mesa-anv-display-gap.md` — companion file; monado
  side is clean
