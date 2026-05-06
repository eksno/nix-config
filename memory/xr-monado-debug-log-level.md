---
type: reference
title: monado-rayneo's RAYNEO_* logs default to INFO — set XRT_LOG=debug to see init flow
created: 2026-05-07
---

Critical Rayneo init lines are emitted at DEBUG level and are invisible
in the default log. Set `XRT_LOG=debug` before launching monado-service
when debugging glasses init.

## Macro definitions

`.research/src/monado/src/xrt/drivers/rayneo/rayneo_hmd.c:45-48`:

```c
#define RAYNEO_DEBUG(hmd, ...) U_LOG_XDEV_IFL_D(&(hmd)->base, (hmd)->log_level, __VA_ARGS__)
#define RAYNEO_INFO(hmd, ...)  U_LOG_XDEV_IFL_I(&(hmd)->base, (hmd)->log_level, __VA_ARGS__)
#define RAYNEO_WARN(hmd, ...)  U_LOG_XDEV_IFL_W(&(hmd)->base, (hmd)->log_level, __VA_ARGS__)
#define RAYNEO_ERROR(hmd, ...) U_LOG_XDEV_IFL_E(&(hmd)->base, (hmd)->log_level, __VA_ARGS__)
```

`(hmd)->log_level` defaults to `U_LOGGING_INFO`, so DEBUG lines drop.

## What's invisible at default INFO

- `rayneo_hmd.c:495` — `"Switching to 3D mode..."` (DEBUG)
- `rayneo_hmd.c:506` — `"3D mode confirmed, waiting for settle..."` (DEBUG)

## What's visible at INFO

- `rayneo_hmd.c:497` — `"Failed to send 3D mode request"` (WARN)
- `rayneo_hmd.c:512` — `"3D mode switch timeout"` (WARN)

If you see neither the debug "Switching..." nor the warn "Failed/timeout",
SwitchTo3D either succeeded silently or was never invoked — you can't tell
which without flipping log level.

## How to apply

In any monado launcher / runner:

```bash
export XRT_LOG=debug
exec monado-service ...
```

The `.scratch/wayvr-trace/run-strace-v2.sh` runner has this on line 78.
For ad-hoc launches, just `XRT_LOG=debug monado-service`.

`XRT_LOG` accepts `trace|debug|info|warn|error` and gates `U_LOGGING_*`
across all monado drivers, not just rayneo.
