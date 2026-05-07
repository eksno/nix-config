---
type: project
title: Rayneo Air 4 Pro replug can come back as USB-only (no DP altmode)
created: 2026-05-07
---

When unplugging and replugging the Rayneo Air 4 Pro to re-arm Hyprland's
`wp-drm-lease-v1` connector advertisement, the replug sometimes comes
back **USB-only** — DP altmode is NOT re-negotiated. The glasses appear
in `lsusb` and the HID interface binds, but `card1-DP-2/status` stays
`disconnected` and Hyprland never sees the connector.

## How to detect

1. `lsusb | rg 1bbb` — USB side present (this part is reliable).
2. `cat /sys/class/typec/port1-partner/accessory_mode` — should read
   anything BUT `none`. If it says `none`, DP altmode failed.
3. `cat /sys/class/typec/port1-partner/usb_mode` — `[usb2]` alone =
   no altmode; should typically include or be paired with a DP-altmode
   subdir.
4. `find /sys/class/typec -name svid` — should list the Rayneo's
   altmode SVID (`ff01` for DisplayPort). If find returns empty, no
   altmode entered.
5. `cat /sys/class/drm/card1-DP-2/status` — `disconnected` despite
   USB present confirms DP-altmode failure.

## Why it happens

USB-C DP altmode negotiation is direction-sensitive on Intel
Thunderbolt/USB4 controllers. Cable orientation at the *laptop* end
matters; a cable that does USB but not DP altmode is also a known
Rayneo gotcha (see `xr-rayneo-hardware.md`). Holding the USB device
exclusively (e.g. an orphan monado-service still alive from a prior
run with `USBDEVFS_DISCONNECT_CLAIM`) appears to interfere with the
re-enumeration too — kill stale monado processes BEFORE the replug,
not after.

## Fix order (cheapest first)

1. Kill any stale `monado-service` / `strace -- monado-service` from
   prior runs. Verify with `pgrep`. Soft-USB-reset via
   `/sys/bus/usb/drivers/usb/{unbind,bind}` if needed (see
   `xr-monado-sigkill-usb-stuck.md`).
2. Unplug glasses, **wait 5+ seconds**, replug. Watch:
   `journalctl -kf | rg -i 'typec|tcpm|displayport|drm.*DP-2'`
3. If still USB-only: **flip the USB-C cable orientation 180°** at the
   laptop end. Plug back in. Wait again.
4. If still USB-only: **try the other USB-C port** on the laptop.
5. If still USB-only: **swap the cable**. A power-only or USB-only
   cable will never enter DP altmode — `xr-rayneo-hardware.md` has
   the cable-quality recipe.

## How to apply

Before re-arming `wp-drm-lease-v1` for a fresh run, ALWAYS verify:

```
test "$(cat /sys/class/drm/card1-DP-2/status)" = connected || \
  echo "DP altmode missing — replug or flip cable"
```

If `disconnected`, do not relaunch the runner — fix the cable layer
first.
