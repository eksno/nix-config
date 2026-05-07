---
type: project
title: lewis EC firmware refuses to register CAMs for partners that DO advertise DP altmode (deeper than xr-lewis-altmode-discovery-stuck)
created: 2026-05-08
status: recovered 2026-05-08 evening (cause unknown)
---

## STATUS UPDATE 2026-05-08 evening

DP altmode came back without us deliberately fixing anything. The
glasses now appear as `DP-1` 1920x1080@120 with `dpmsStatus=true`,
`mirrorOf=none` — a fully active independent display, content
visible on the panel. **`UCSI debugfs still reports the same wedge
fingerprint** (GET_CAM_SUPPORTED=0, accessory_mode=none) even while
the i915 DP path is clearly engaged. So **don't trust the UCSI
fingerprint as definitive**: i915 can negotiate DP independently of
what UCSI debugfs sees. Use `hyprctl monitors -j` or
`/sys/class/drm/card1-DP-*/status` for the source of truth on
whether the glasses panel will actually scan out.

Plausible recovery triggers (none confirmed):
- The `hyprctl output create headless` × 4 + `output remove` cycle
  during Phase 4A testing may have nudged Hyprland to re-evaluate
  real outputs, forcing a fresh DP probe.
- Time-based EC lockout expiry (we did wait several hours over
  multiple reboots).
- Kernel cmdline thrash (3 reboots on 2026-05-08 with different
  power-saving flags) accidentally hit a state the EC was happier
  with.
- Plain replug after the cmdline-revert reboot.

Because the cause is unknown, expect this to recur. The 5-command
UCSI fingerprint below remains the right detection recipe, but
**also check `hyprctl monitors -j | jq '.[].dpmsStatus'`** before
declaring it broken — UCSI may misreport.

## What this is

A more thorough diagnosis than the earlier
`xr-lewis-altmode-discovery-stuck.md`. After cold-cycling (shutdown +
30s power button hold) on lewis (ASUS Zenbook 14 UX3405MA, BIOS
UX3405MA.301, 2023-12-15, Intel Meteor Lake-P), DP altmode still
doesn't enter for the Rayneo Air 4 Pro. The bug is **EC firmware
refusing to register a CAM** even though the partner correctly
advertises DP altmode SVID 0xff01.

## Confirmed via direct UCSI debugfs queries

The `/sys/kernel/debug/usb/ucsi/USBC000:00/{command,response}` interface
lets you issue raw UCSI commands. Useful one-liner to confirm this
specific failure mode is present:

```bash
# 1. GET_CAPABILITY — confirms features = 0x0000 (no ALT_MODE_DETAILS bit)
echo 0x0000000000000006 | sudo tee /sys/kernel/debug/usb/ucsi/USBC000:00/command
sudo cat /sys/kernel/debug/usb/ucsi/USBC000:00/response
# expect: ...0000...0200004146 → features field at bytes 5-6 is 0x0000

# 2. GET_CONNECTOR_STATUS for port 1 (con=1 = port0 in Linux)
echo 0x0000000000010012 | sudo tee /sys/kernel/debug/usb/ucsi/USBC000:00/command
sudo cat /sys/kernel/debug/usb/ucsi/USBC000:00/response
# expect: byte 2 has bits 5-6 = 10 = "altmode capable" (flags=2)
# i.e. low byte includes 0x5b = 0101_1011

# 3. GET_ALTERNATE_MODES on con=1, partner SOP
echo 0x000000000001000c | sudo tee /sys/kernel/debug/usb/ucsi/USBC000:00/command
sudo cat /sys/kernel/debug/usb/ucsi/USBC000:00/response
# expect: ...0000000405ff01 → SVID 0xff01 (DP), VDO 0x00000405

# 4. GET_CAM_SUPPORTED on con=1
echo 0x000000000001000d | sudo tee /sys/kernel/debug/usb/ucsi/USBC000:00/command
sudo cat /sys/kernel/debug/usb/ucsi/USBC000:00/response
# expect: 0x...0000 → ZERO CAMs supported (the bug fingerprint)

# 5. (optional) try SET_NEW_CAM to force entry — will time out
echo 0x000002040081000f | sudo tee /sys/kernel/debug/usb/ucsi/USBC000:00/command
# expect: tee: ... Connection timed out
```

The fingerprint is: **partner advertises DP altmode (3) succeeds**, but
**GET_CAM_SUPPORTED (4) returns zero AND SET_NEW_CAM (5) times out**.
The EC has the partner data but won't create a CAM entry on the port,
so no `ucsi_register_altmode` event ever fires kernel-side.

## What the kernel sees

Function trace of `ucsi_*` during plug shows:

- `ucsi_register_partner.isra.0` — partner registers ✓
- `ucsi_register_partner_pdos`, `ucsi_register_device_pdos` — PDOs registered ✓
- ❌ NEVER: `ucsi_register_altmodes`, `ucsi_check_altmodes`, `ucsi_register_displayport`

Reason: `ucsi_handle_connector_change` only calls `ucsi_check_altmodes`
when `con->status.change & UCSI_CONSTAT_CAM_CHANGE` (bit 10) is set.
The 3 connector-change events captured during plug have change values
`0x4800`, `0x5800`, `0x0a00` — bit 10 is never set. The EC never tells
the kernel "altmode availability changed" because it never created an
altmode for the port.

`/sys/class/typec/port0-partner/` shows `accessory_mode=none`,
`usb_power_delivery_revision=0.0`, no `port0-partner.0/` altmode subdir,
and `find /sys/class/typec -name svid` returns nothing.

## What does NOT recover

- Cable orientation flip — both orientations
- USB-C port swap (top port vs bottom port)
- 5-minute glasses-unplugged (capacitor discharge of glasses)
- `systemctl suspend` + wake (re-inits EC mailbox; doesn't reset altmode policy)
- `sudo reboot` (EC firmware state survives soft reboot)
- Cold cycle: `shutdown -h now` + AC unplug + 30s power-button hold (does
  reset some EC state but not enough)
- `ucsi_acpi` driver unbind/rebind on `USBC000:00`
- xhci PCI driver unbind/rebind on `0000:00:14.0`
- UCSI `CONNECTOR_RESET` (0x03) via debugfs — succeeds but no behavior change
- UCSI `PPM_RESET` (0x01) — kernel returns "Operation not supported"
- UCSI `SET_NEW_CAM` (0x0f) — times out, EC won't accept it
- Disconnecting charger to test charger-presence theory (no effect)
- `usbcore.autosuspend=-1` — no effect
- BIOS Restore Defaults (F2 → F9 → F10) on 2026-05-08 — no effect; EC
  policy state persists across BIOS NVRAM clear
- Booting with all four aggressive power-saving kernel params dropped
  (`i915.enable_dc=4`, `pcie_aspm=force`, `acpi.ec_no_wakeup=1`,
  `usbcore.autosuspend=1`) — no effect on 2026-05-08; rules out runtime
  EC/USB/display power management as the wedge cause

## Worked once today (2026-05-07 at ~14:12)

The Hyprland aquamarine log on the same NixOS gen `549bd84` (kernel 7.0.3)
shows DP altmode DID succeed earlier the same day:
SmartGlasses connected on DP-1 with EDID, Aquamarine reported the
connector, `wp-drm-lease-v1` advertised it, monado leased it. Then it
broke and stayed broken for the rest of the day across multiple cold
cycles. The firmware is not permanently broken — it's reaching a wedged
state with non-trivial recovery requirements.

## Likely root causes (unconfirmed)

1. **BIOS UX3405MA.301 has a USB-C altmode regression that triggers
   after N plug/unplug cycles** — ship BIOS for this Zenbook is from
   2023-12, ~2.5 years stale. ASUS has likely shipped BIOS revisions
   that fix this.
2. **Cable e-marker handshake quirk** — same cable works on phone but
   lewis's TBT4 controller is stricter. `vconn_source = no` on both
   ports indicates lewis isn't supplying VCONN, so e-marker wasn't
   queried.
3. **EC's altmode rate-limiter or failure-counter** locks after some
   threshold of failed attempts and only resets via BIOS clear.

## Workarounds

In order of cost:

1. **Run on the laptop screen instead** — sideview / mouse mode through
   xr-driver still works fine over USB+HID. DP altmode isn't required
   for IMU pose. Phase 3.10+ work that needs the glasses panel is
   blocked, but Phase 3.7 (monado retry patch) verification can wait.
2. **Try a different DP-altmode-capable cable** (Thunderbolt 4 or
   certified USB-C 3.x with DP altmode) before assuming it's a BIOS
   issue.
3. **BIOS update** via ASUS:
   https://www.asus.com/laptops/for-home/zenbook/asus-zenbook-14-oled-ux3405ma/helpdesk_bios/
4. **CMOS reset / battery-disconnect pinhole reset** if available on
   this model.

## Why this lives in memory (not LEARNINGS.md)

This is project state — the wedge is in lewis's EC firmware right now,
might recover on its own or after BIOS update. Once altmode comes back
this memory should be archived/marked-resolved. The diagnostic recipe
above is what makes it worth keeping: future-Claude can run the 5
UCSI commands in 30 seconds and fingerprint the failure.
