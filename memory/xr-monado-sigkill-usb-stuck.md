---
type: project
title: SIGKILL on monado-service leaves Rayneo USB half-claimed — soft-reset to recover
created: 2026-05-07
---

`pkill -9 monado-service` (or any SIGKILL) leaves the kernel's
`USBDEVFS_DISCONNECT_CLAIM` record unwound. Subsequent `libusb_open()`
fails with `Failed to open USB device (1bbb:af50)` even though the
device file still exists with correct permissions.

This compounds the lesson from `xr-shutdown-discipline.md` (use SIGINT
+ wait for DRM-grabbing processes) — even ignoring DRM, USB state alone
makes SIGKILL costly.

## Recovery without unplugging

Soft-bind/unbind via sysfs:

```bash
# Find the topology path — bus 3, port path 2 in the example below.
readlink /sys/bus/usb/devices/3-2     # confirm it's the Rayneo

sudo sh -c 'echo 3-2 > /sys/bus/usb/drivers/usb/unbind ; \
            sleep 1 ; \
            echo 3-2 > /sys/bus/usb/drivers/usb/bind'
```

After bind, `/dev/bus/usb/00X/00Y` is fresh (new minor number possible),
and any user with `users` group access can open it.

`3-2` is the bus + port path on `lewis` for the Rayneo's current connection.
Rederive if the cable is moved to a different port.

## Why this happens

`USBDEVFS_DISCONNECT_CLAIM` (used by `monado-rayneo`'s `rayneo_usb.c`)
detaches kernel drivers and claims the interface. The claim is owned by
the file descriptor; on graceful close (SIGINT path) libusb / the kernel
release it. SIGKILL skips the close path, so the kernel still thinks the
interface is claimed by a now-dead PID until the device is rebound.

## How to apply

- Default path: never SIGKILL monado. SIGINT, wait, then escalate only
  if needed (`xr-shutdown-discipline.md`).
- If you DID SIGKILL and now see `Failed to open USB device`: do the
  unbind/bind dance above. Replug works too but is unnecessary friction.
- Pair with `pgrep -af monado-service` to confirm no stale processes
  are still holding the fd before re-running.
