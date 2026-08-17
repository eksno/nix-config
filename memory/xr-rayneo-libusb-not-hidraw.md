---
type: project
title: Rayneo glasses talk via libusb at /dev/bus/usb, NOT /dev/hidraw*
created: 2026-05-07
---

The Rayneo Air 4 Pro (`1bbb:af50`) is opened by both `xr-driver` and
`monado-rayneo` through **libusb / usbdevfs**, not the kernel HID layer.
Don't conflate it with hidraw devices.

## Where it actually lives

- `/dev/bus/usb/003/003` (bus.dev varies by enumeration order). Mode
  `crw-rw---- root:users 660`. User `jorge` is in group `users`, so
  access works without any extra udev rule for permissions.
- `lsusb -d 1bbb:af50` confirms vendor/product. `udevadm info
  /dev/bus/usb/003/003` shows the driver path.

## What's NOT the glasses

On `lewis`, `/dev/hidraw2` and `/dev/hidraw3` exist but are unrelated:

- one is the **Intel Meteor Lake-P Integrated Sensor Hub (ISH)**
- one is the **I2C touchpad**

A previous subagent assumed the hidraws were the Rayneo. They are not.
`udevadm info /dev/hidraw{2,3}` walks the parent chain to confirm.

## How monado-rayneo opens it

`.research/src/monado/src/xrt/drivers/rayneo/rayneo_usb.c` uses:

- `USBDEVFS_DISCONNECT_CLAIM` to detach any kernel driver and claim the
  interface
- `USBDEVFS_SUBMITURB` / `USBDEVFS_REAPURBNDELAY` for IO

Confirmed via strace: ~2.4M usbdevfs ioctls on the rayneo USB thread.
This is why a process holding the device blocks every other process —
it's an exclusive interface claim, not a shared HID open.

## How to apply

- Don't add hidraw udev rules expecting them to affect the Rayneo.
- Don't grep `/dev/hidraw*` looking for the glasses.
- For permission issues, check group membership of `users` on
  `/dev/bus/usb/003/00X`, not hidraw ACLs.
- The existing `MODE="0660", GROUP="users"` udev rule in
  `system/lib/xr/glasses-edid/default.nix` covers the USB node and is
  what unblocks `jorge`'s access at boot.
