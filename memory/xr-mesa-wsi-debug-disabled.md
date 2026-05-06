---
type: reference
title: Mesa wsi_display tracing is compile-time disabled
created: 2026-05-06
---

`MESA_VK_WSI_DEBUG=display` (and `WSI_DEBUG=display`) print **nothing**
for the WSI display path on stock Mesa builds — including ours.

The `wsi_display_debug` and `wsi_display_debug_code` macros in
`src/vulkan/wsi/wsi_common_display.c:99-105` are wrapped in `#if 0`:

```c
#if 0
#define wsi_display_debug(...) fprintf(stderr, __VA_ARGS__)
#define wsi_display_debug_code(...)     __VA_ARGS__
#else
#define wsi_display_debug(...)
#define wsi_display_debug_code(...)
#endif
```

So every `wsi_display_debug(...)` call site in that file expands to
nothing at compile time. The env vars *would* be checked elsewhere in
Mesa (and they do enable other WSI traces), but for the KHR_display /
direct-mode path specifically, you get silence.

## To get tracing

Patch Mesa to flip `#if 0` → `#if 1` in `wsi_common_display.c` and
rebuild. Out of scope for nix-config debugging unless we hit a wall
that needs it.

## How this came up

Spent time during the v3 SURFACE_LOST diagnostic setting
`MESA_VK_WSI_DEBUG=display` and getting nothing in the log, suspecting
env-var propagation problems. Verified by greppping the Mesa source
in `.research/src/mesa/` (see `xr-research-corpus.md`). It's the macro,
not our env handling.

## Useful negative learning

If a Mesa env var seems to do nothing, grep the Mesa source for the
matching `*_debug` macro definition before assuming you're holding the
env wrong. The pattern of `#if 0`'d debug macros is common in Mesa.
