---
type: project
title: xr-driver and monado-rayneo conflict over the Rayneo USB device — mask, don't stop
created: 2026-05-07
---

`xr-driver` and `monado-rayneo` both want exclusive `USBDEVFS_DISCONNECT_CLAIM`
on `1bbb:af50`. `systemctl --user stop xr-driver` is not enough — the
unit auto-restarts and races monado for the claim.

## What goes wrong with `stop`

1. Launcher runs `systemctl --user stop xr-driver`.
2. Unit restart policy / udev hotplug RUN+= rule (exact mechanism not
   yet pinpointed) re-spawns xr-driver within seconds.
3. monado-rayneo's `rayneo_phase_init` calls libusb_open → racey CLAIM.
4. If xr-driver wins for >30 retries (a few seconds), monado prints
   `Failed to open USB device (1bbb:af50)` and gives up — see
   `init_failed_after_30_retries` in `rayneo_hmd.c`.

## The workaround that works

`mask` makes the unit a symlink to `/dev/null`, blocking any auto-restart
for the whole session:

```bash
systemctl --user mask xr-driver
# ... run monado ...
systemctl --user unmask xr-driver
systemctl --user start xr-driver   # if you want it back this session
```

The v2 runner at `.scratch/wayvr-trace/run-strace-v2.sh` uses this.

## Side effect of masking

`xr-driver` is what calls `SwitchTo3D` via the SDK and what writes
`sbs_mode_enabled=true` to `/dev/shm/xr_driver_state`. With it masked,
monado-rayneo's own SwitchTo3D path runs (see
`xr-monado-debug-log-level.md` for visibility). Brightness / SBS state
that xr-driver normally manages may stay at firmware default — relevant
when debugging "panel is dark" symptoms.

## How to apply

- For monado-only debug runs: mask xr-driver, don't stop.
- After the run: unmask. Don't leave the system with xr-driver masked
  permanently — non-XR mouse-mode and breezy_desktop SHM both depend
  on it.
- If `Failed to open USB device` shows up despite masking: check for
  another process (lingering `monado-service`, stale `xreal-air`) that
  may have an open libusb handle. See `xr-monado-sigkill-usb-stuck.md`.
