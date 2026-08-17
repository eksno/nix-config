---
type: reference
title: monado-rayneo uses its own RAYNEO_LOG env var (default WARN), XRT_LOG=debug is NOT enough
created: 2026-05-07
updated: 2026-05-07
---

**XRT_LOG=debug alone is NOT enough to see rayneo init lines.** The rayneo
driver registers its own per-driver log option that defaults to WARN; the
global `XRT_LOG` doesn't override it. You need both, but `RAYNEO_LOG=debug`
is the one that actually matters for the rayneo driver.

## Why the per-driver option exists

`.research/src/monado/src/xrt/drivers/rayneo/rayneo_hmd.c:39`:

```c
DEBUG_GET_ONCE_LOG_OPTION(rayneo_log, "RAYNEO_LOG", U_LOGGING_WARN)
```

`(hmd)->log_level` is initialized from this option, so all
`RAYNEO_DEBUG`/`RAYNEO_INFO` macros are suppressed by default. Setting
`XRT_LOG=debug` only changes the global default — drivers with their own
`DEBUG_GET_ONCE_LOG_OPTION` ignore it.

The macros at `rayneo_hmd.c:45-48`:

```c
#define RAYNEO_DEBUG(hmd, ...) U_LOG_XDEV_IFL_D(&(hmd)->base, (hmd)->log_level, __VA_ARGS__)
#define RAYNEO_INFO(hmd, ...)  U_LOG_XDEV_IFL_I(&(hmd)->base, (hmd)->log_level, __VA_ARGS__)
#define RAYNEO_WARN(hmd, ...)  U_LOG_XDEV_IFL_W(&(hmd)->base, (hmd)->log_level, __VA_ARGS__)
#define RAYNEO_ERROR(hmd, ...) U_LOG_XDEV_IFL_E(&(hmd)->base, (hmd)->log_level, __VA_ARGS__)
```

## What's invisible at default WARN

- `rayneo_hmd.c:495` — `"Switching to 3D mode..."` (DEBUG)
- `rayneo_hmd.c:506` — `"3D mode confirmed, waiting for settle..."` (DEBUG)
- All IMU stream init lines (DEBUG/INFO)
- All `phase_init` progress lines (DEBUG)

## What's visible at default WARN

- `rayneo_hmd.c:497` — `"Failed to send 3D mode request"` (WARN)
- `rayneo_hmd.c:512` — `"3D mode switch timeout"` (WARN)
- `"Failed to open USB device"` retry lines (WARN)

If neither the DEBUG "Switching..." NOR the WARN "Failed/timeout" appears
in the log, SwitchTo3D either succeeded silently OR was never invoked —
you can't tell which without flipping the log level.

## Other driver-specific env vars that exist on monado-rayneo

- `RAYNEO_LOG` — per-driver log level (default WARN)
- `RAYNEO_FW_LOG` — surface firmware-side log lines
- `RAYNEO_DISABLE_MAG` — disable magnetometer fusion

(Confirmed via `strings monado-service | rg RAYNEO_` on the active build.)

## How to apply

In any monado launcher / runner that's debugging Rayneo:

```bash
export XRT_LOG=debug         # global default (still useful for non-rayneo)
export RAYNEO_LOG=debug      # rayneo driver — THE one that matters
exec monado-service ...
```

The `.scratch/wayvr-trace/run-strace-v2.sh` runner sets BOTH (lines 80–82
after the 2026-05-07 update). For ad-hoc launches:

```bash
RAYNEO_LOG=debug XRT_LOG=debug monado-service
```

`RAYNEO_LOG` accepts `trace|debug|info|warn|error` (same enum as XRT_LOG).
