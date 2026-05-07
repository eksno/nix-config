---
type: project
title: ASUS TbtTypeC + UCSI gets stuck on lewis — ucsi_acpi rebind alone doesn't fix it
created: 2026-05-07
---

`lewis` (ASUS laptop with Thunderbolt 4 / USB4) has a recurring failure
mode where `ucsi_acpi` loses communication with the embedded controller,
producing repeated `GET_CONNECTOR_STATUS failed (-70)` errors in dmesg.
Once this happens, **plug/unplug events on USB-C ports are no longer
forwarded to userspace**. New devices show up in xhci enumeration (USB
HID at full-speed) but `accessory_mode` stays `none` for all partners,
no `svid` directories appear, and DP altmode never engages.

## Identification

- `dmesg` shows: `ACPI: SSDT ... _ASUS_ TbtTypeC ...` at boot
- `dmesg` shows: `ucsi_acpi USBC000:00: GET_CONNECTOR_STATUS failed (-70)`
- `cat /sys/class/typec/port*-partner/accessory_mode` returns `none` for
  partners that should support DP altmode (e.g. the Rayneo Air 4 Pro)
- `find /sys/class/typec -name svid` returns zero paths
- USB enumeration in dmesg shows `new full-speed USB device` (1.1 speed)
  even for cables that previously did high-speed + DP altmode
- UCSI typec controller is at platform device `USBC000:00`, driven by
  `ucsi_acpi`

## What does NOT fix it

- Cable flipping at the laptop end (orientation change)
- Trying the other USB-C port
- xhci PCI device unbind/rebind on `0000:00:14.0` (xhci is the USB host;
  altmode is a separate platform path)
- `ucsi_acpi` driver unbind/rebind on `USBC000:00`
- USB device unbind/rebind via `/sys/bus/usb/drivers/usb`
- `udevadm trigger`
- `hyprctl reload`

These all leave `accessory_mode=none` because the underlying ACPI/EC bus
itself is stuck — the driver can be cycled but the channel it talks
through is not.

## What DOES fix it

1. **`systemctl suspend` + wake** — ACPI suspend re-initializes the EC.
   Cheapest non-destructive fix; preserves session state.
2. **`sudo reboot`** — nuclear option, always works.

After either, plug events resume normally and altmode discovery works
again. Capture this in memory because the symptom is misleading: it
looks like a cable problem (USB-only enumeration, no DP) but it's
actually a software/firmware state issue that's invisible until
suspend/resume.

## Why this happens

Suspected: long-running session (this case: ~14 hours uptime) with
many connect/disconnect cycles eventually corrupts the UCSI command
queue or EC mailbox. Other ASUS users have reported similar patterns
on Linux 6.x, with various distro-specific kernel patches discussed
upstream but no permanent fix as of 2026-05.

## How to apply

Detect by grepping `dmesg` for `ucsi_acpi.*-70` after replugging the
Rayneo. If present and `accessory_mode=none` despite USB enumeration
working, **don't keep wiggling the cable** — go straight to
`systemctl suspend`. Re-test after wake.
