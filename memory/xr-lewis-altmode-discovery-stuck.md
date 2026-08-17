---
type: project
title: lewis EC altmode discovery state machine gets stuck — UCSI sees partner but never registers altmodes; cold power cycle required
created: 2026-05-07
---

After a long Hyprland session with many USB-C plug/unplug cycles on
the Rayneo Air 4 Pro, lewis's USB-C / TBT4 controller can get into a
state where **DP altmode never enters** even after `sudo reboot`.
Same cable + same glasses successfully negotiates DP altmode on a
phone — proving the cable+glasses combo is fine. The fault is on
lewis's USB-C controller firmware / EC.

## The fingerprint after this happens

Plug glasses, then check UCSI tracing:

```
echo | sudo tee /sys/kernel/tracing/trace
echo 1 | sudo tee /sys/kernel/tracing/events/ucsi/enable
# unplug + replug glasses
echo 0 | sudo tee /sys/kernel/tracing/events/ucsi/enable
sudo head -100 /sys/kernel/tracing/trace
```

You see:
- `ucsi_connector_change: ... connected=1, partner_type=2` (UFP, correct)
- ZERO `ucsi_register_altmode` events

`/sys/class/typec/port0-partner/` exists with `pd2/` subdirectory but
NO `port0-partner.0/` altmode subdir. `accessory_mode` reads `none`.
`find /sys/class/typec -name svid` returns nothing.

Meanwhile dmesg has:
- USB enumeration successful (`new full-speed USB device`,
  `idVendor=1bbb`, `Product: RayNeo AR Glasses`)
- ZERO `displayport|altmode|svid|discover|enter_mode` lines anywhere
  in the whole boot

UCSI is not erroring (`-70` is absent on a fresh boot), it's just
silently skipping altmode discovery. PD2 negotiation completes; the
EC's altmode state machine doesn't follow up with Discover_SVIDs.

## What does NOT fix it

- Cable orientation flip
- USB-C port swap (top vs bottom)
- `ucsi_acpi` driver unbind/rebind on `USBC000:00`
- xhci PCI device unbind/rebind on `0000:00:14.0`
- `systemctl suspend` + wake (s2idle does not reset EC firmware state)
- `sudo reboot` (soft reboot does NOT reset EC NVRAM-backed state on
  this ASUS / Meteor Lake-P platform)
- `usbcore.autosuspend=-1` runtime change
- Disabling `xr-driver` / killing all userspace claimants

## What DOES fix it (suspected — needs validation)

**Cold power cycle**:

1. `sudo shutdown -h now`
2. Unplug charger, USB-C peripherals, everything
3. **Hold power button for 30 seconds** (forces EC reset)
4. Plug charger back in, power on
5. Plug glasses, verify with the UCSI trace recipe above. Want at
   least one `ucsi_register_altmode` event after the connect event,
   and `port0-partner.0/svid` to exist.

If cold cycle doesn't fix it, escalation paths to consider:
- BIOS update if available (ASUS sometimes ships USB-C firmware fixes)
- BIOS option named "USB Power Delivery in Soft Off" / "USB-C
  Functions" / "Type-C Always On" — toggling can clear latched state

## What still works while in this state

- xr-driver / IMU / HID at USB full-speed (1bbb:af50 enumerates fine).
  Sideview / mouse mode unaffected.
- USB device authorized (`/sys/bus/usb/devices/3-1/authorized = 1`).

## What does NOT work in this state

- DP altmode → no DRM lease → no monado direct-mode display
- Phase 3.10 verification on real hardware

## Why suspend/reboot don't fix it

UCSI errors `GET_CONNECTOR_STATUS failed (-70)` (seen in the same-day
session before reboot) indicate the EC's UCSI mailbox got desynced.
After the soft reboot, those errors are gone but **altmode-discovery
state in the EC firmware is preserved across reboot** — the EC chip
itself isn't power-cycled. Only a full power-off + hold-power-button
forces the EC to re-init from BIOS-defaults.

Prior session memory: `xr-asus-ucsi-stuck.md` claimed `systemctl
suspend` fixes it. That was wrong / specific to a different sub-state.
This memory is the corrected, more general writeup.

## How to apply

If `find /sys/class/typec -name svid` is empty AND
`port0-partner/accessory_mode` reads `none` AND UCSI tracing shows
`ucsi_connector_change` with no `ucsi_register_altmode`:

1. Don't try to fix it via reboot — it won't work.
2. Tell Jorge: cold power cycle is the next step, hold power 30s.
3. Don't waste time on cable swap (he tested on phone, cable is fine).
4. xr-driver / IMU still works; sideview/mouse mode is unblocked.
