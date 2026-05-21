---
type: project
title: lewis EC firmware refuses to register CAMs for partners that DO advertise DP altmode (deeper than xr-lewis-altmode-discovery-stuck)
created: 2026-05-08
status: **RECOVERED 2026-05-22 ~00:55.** Glasses now show up as a real `DP-2` monitor in Hyprland (1920x1080@120, EDID "Technical Concepts Ltd SmartGlasses"), DP-2 status=connected with non-zero EDID. Recovery sequence: BIOS UX3405MA.301→311 flash (2026-05-21) + drop `acpi.ec_no_wakeup=1` from `system/lib/device/intel/default.nix` + drop `drm.edid_firmware=DP-1,DP-2:...` from `system/lib/xr/glasses-edid/default.nix` + reboot to gen 62. **Causally important point**: UCSI debugfs STILL reports the wedge fingerprint (`accessory_mode=none`, no altmode subdir) even while DP altmode is clearly active — matches the existing `xr-ec-altmode-suspend-replug-untested.md` / "UCSI lies" LEARNINGS pattern. The three-agent claim "lockout lives in EC firmware flash, only recovery is BIOS reflash" was at best incomplete: a kernel-cmdline / BIOS combination matters.
---

## STATUS UPDATE 2026-05-22 ~00:55 — RECOVERED

After exhausting cheap probes post-BIOS-flash (port swap, cable
orientation, suspend-replug, xr-driver mask), Jorge dropped TWO kernel
cmdline params via NixOS rebuild + reboot (gen 62):

1. **`acpi.ec_no_wakeup=1`** removed from
   `system/lib/device/intel/default.nix:21` (commented).
2. **`drm.edid_firmware=DP-1:edid/rayneo-air4pro-glasses.bin,DP-2:edid/rayneo-air4pro-glasses.bin`**
   removed from `system/lib/xr/glasses-edid/default.nix:47-49`
   (commented).

Commit: `543ea9b` (`test(xr/altmode): drop acpi.ec_no_wakeup + EDID firmware override`).

**First plug post-reboot: glasses worked.**

Working-state snapshot:

```
$ cat /sys/class/dmi/id/bios_version
UX3405MA.311
$ cat /proc/cmdline | tr ' ' '\n' | grep -iE "ec_no_wakeup|edid"
(empty — both dropped)

$ hyprctl monitors all | grep -A4 DP-2
Monitor DP-2 (ID 1):
    1920x1080@120.01300 at 2304x0
    description: Technical Concepts Ltd SmartGlasses 0x00000011
    make: Technical Concepts Ltd
    model: SmartGlasses

$ cat /sys/class/drm/card1-DP-2/status
connected
$ cat /sys/class/drm/card1-DP-2/dpms
On
```

Hyprland treats DP-2 as a regular external monitor extending eDP-1
to the right at 2304x0. Real EDID is being read (the
"Technical Concepts Ltd SmartGlasses" description comes from the
glasses' actual EDID, not from the gitignored override blob).

### CRITICAL — what UCSI says vs. ground truth

UCSI / typec subsystem STILL reports the wedge fingerprint while
DP altmode is clearly active:

```
$ cat /sys/class/typec/port1-partner/accessory_mode
none
$ ls /sys/class/typec/port*-partner.* 2>/dev/null
(no altmode subdirs)
```

This matches the existing `LEARNINGS.md` entry "UCSI debugfs is NOT
a reliable signal for actual altmode state" — i915 negotiates DP
altmode independently of what UCSI's cached state shows. **Source
of truth for "are the glasses working as a display" is
`hyprctl monitors -j` or `card1-DP-2/{status,edid,dpms}`, not UCSI.**

### What we DON'T know yet (causal isolation pending)

We can't say which of the three changes was load-bearing without
more tests:

- (a) BIOS UX3405MA.301 → .311 alone
- (b) Drop `acpi.ec_no_wakeup=1`
- (c) Drop `drm.edid_firmware=...` (EDID firmware override)
- Or some combination requires multiple together

The 2026-05-08 test "rules out runtime EC/USB/display power
management as the wedge cause" dropped four power-saving params but
did NOT touch the EDID firmware override. So (c) is the new variable
this session, and the leading suspect for "the actual blocker".

Mechanism hypothesis (unconfirmed): the synthetic EDID firmware
override forces `status=connected` on DP-1/DP-2 even when there's no
real DP link. The i915 DP probe / link training sequence might
short-circuit when it sees a connector already reporting connected
with a parsed EDID — skipping the altmode-request handshake that
would normally tell the EC to enable DP altmode for this partner.
Removing the override forces i915 to run the full DP probe, which
includes requesting altmode entry, which the EC then accepts.

### Suggested isolation tests (optional, only if Jorge wants
to understand which lever mattered)

1. Re-enable `drm.edid_firmware=...` only (keep `acpi.ec_no_wakeup=1`
   off) → rebuild + reboot → test. If glasses break: EDID override
   was the real culprit. If they still work: not load-bearing alone.
2. Re-enable `acpi.ec_no_wakeup=1` only (keep override off) →
   rebuild + reboot → test. Symmetric to (1).
3. If both individually fine: order/interaction may matter (less
   likely).

These tests are NOT required — the system works now. They're for
the curious.

### Implication for monado / VR path

The EDID firmware override was the mechanism that made
`wp-drm-lease-v1` advertise DP-2 to monado for VR mode. With the
override off, the glasses are a regular monitor (desktop-class),
and monado's direct DRM lease path won't see them as leasable. Any
future XR/VR work that needs direct mode would need to re-enable
the override — but per the hypothesis above, doing so may re-wedge
the EC altmode.

This is a real workflow tension: **basic display mode (works now,
override off) vs. VR mode (needs override, may break altmode).**
Worth thinking through before deciding to keep the override
permanently disabled.

## STATUS UPDATE 2026-05-21 — BIOS 301→311 flash did NOT recover (now superseded by 2026-05-22 recovery above)

Jorge flashed the official ASUS UX3405MAAS.311 capsule via "ASUS
Firmware Update → via Storage Device(s)". `cat /sys/class/dmi/id/bios_version`
confirms `UX3405MA.311`, date `06/06/2025`. No errors during flash,
auto-reboot succeeded.

**On the FIRST plug of the glasses post-flash, the wedge fingerprint
was identical to pre-flash:**

```
/sys/class/typec/port1-partner/accessory_mode: none
/sys/class/typec/port1-partner/number_of_alternate_modes: 0
(no port1-partner.0/ altmode subdir)
/sys/class/drm/card1-DP-2/edid: 0 bytes  (the "connected" status is
                                          the EDID firmware override lying)
```

Kernel journal on plug shows **only USB HID enumeration** — zero
typec / UCSI / DP altmode events:

```
usb 3-2: new full-speed USB device number 5 using xhci_hcd
usb 3-2: New USB device found, idVendor=1bbb, idProduct=af50
usb 3-2: Product: RayNeo AR Glasses
hid-generic 0003:1BBB:AF50.0003: hiddev96,hidraw2: USB HID v1.11 Device [RayNeo AR Glasses]
```

This is **the same dead silence as before the BIOS update.** The
EC isn't even attempting altmode negotiation.

**What this means.** The three-agent dive's conclusion that
"BIOS update is the only documented recovery path with mechanism
+ precedent" was **the strongest available hypothesis**, citing the
[Slimbook EVO15-A8 case](https://gist.github.com/gnespolino/81abd597153fd19aa2a039f66b8359a3)
as precedent — but that hypothesis is now **provisionally
falsified** for this exact bug on this hardware. Either:

1. UX3405MA.311's EC firmware blob doesn't differ in altmode policy
   from .301 (ASUS may have fixed something else; their changelogs
   on the support page are not specific about altmode).
2. The lockout state is in a flash region BIOS update doesn't reach
   on this model (ASUS bundles EC firmware in the BIOS capsule per
   `fwupdmgr`, but the EC flash policy region may be a separate OTP
   region).
3. The wedge needs a specific recovery sequence post-flash (multiple
   reboots, suspend cycles, specific timing) that we haven't tried.

**Remaining cheap recovery probes** (still untested post-flash):

1. Suspend → wait for `-70` UCSI errors in dmesg → fresh replug.
   See `xr-ec-altmode-suspend-replug-untested.md`. Cost ~30 sec.
2. Try the OTHER USB-C port (we don't know which port Jorge plugged
   into post-flash). 30 sec.
3. Flip USB-C cable orientation. 5 sec.
4. Live USB Fedora 42 (kernel 6.12.x) — diagnostic only, would tell
   us if the wedge follows the kernel or the hardware. ~30 min.

**Stronger escalations** (untested):

- TBT4-certified USB-C cable (rules out cable-classification stricter
  on .311 EC firmware vs phone-tested cable).
- Battery disconnect pinhole if this model has one.
- ASUS RMA / service center — at this point the EC firmware is
  arguably defective vs. ASUS spec, not just stale.

**Apply.** Before recommending BIOS flash as "the" escalation for
this fingerprint on similar ASUS hardware in the future, qualify it
as "Slimbook precedent, but lewis 2026-05-21 BIOS .311 did NOT
recover — may need additional steps or may not work at all." See
the new `asus-zenbook-bios-flash-quirks.md` for the procedure-side
quirks (Zenbook has no Tool tab, utility is "ASUS Firmware Update"
not EZ Flash, use USB-A not USB-C for the stick, etc.).

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
- ASUS-documented EC reset: `shutdown -h now`, AC charger plugged in,
  hold power button 40 seconds (FAQ 1050239) — NO EFFECT on 2026-05-09.
  Procedure deeper than the prior 30s+AC-unplug attempt (cuts EC RAM
  rail), still didn't clear the wedge. Post-reset UCSI fingerprint
  identical: `GET_CAM_SUPPORTED=0`, no altmode subdir on partner,
  panel pure black on connect. Confirms the lockout state is in EC
  NVRAM (or some persistent flash region), not EC RAM. Replug,
  port swap, and orientation flip post-reset all also no-op.

## Where the lockout state lives (2026-05-08 three-agent deep dive)

Three parallel sub-agents (temporal diff, EC NVRAM write paths, cross-
distro/community workarounds) converged on the same answer: the
lockout flag is in the EC firmware's persistent flash region (SPI or
OTP), unreachable from any userspace path on this hardware.

Evidence:

- **DSDT + 21 SSDTs fully dumped and searched** (via `acpidump` +
  `iasl -d`). Zero methods reset/clear UCSI/altmode policy state. The
  UCSI bridge in SSDT19 (`UsbCTabl`, OEM `_ASUS_`) maps the PPM to
  EC0 via shared-memory at EC0:UBCB (offsets 0x04-0x2F at bank 0xC9).
  The kernel drives UCSI via `_DSM` function 1 (write CTL→EC0
  registers) and function 2 (read CCI/MGI←EC0). Standard pattern.
- **`acpi_call` exploration**: only one EC custom command callable
  via WMI is `\ATKD.WMNB(0, 0x00100013, 0x02)` → EC SMFI command 0xB6
  (likely power/perf mode, NOT altmode). No targeted method exists.
- **EC RAM write region**: bank 0xC9 offsets 0x04-0x2F are the live
  UCSI registers — already kernel-writable via `_DSM`. The EC PPM
  ignores `SET_NEW_CAM` (0x0f) writes in the wedge state. RP2E/WP2E
  protect 0x40-0x70 (battery channel, not UCSI). The "register a CAM
  or refuse" decision lives in EC firmware, not in any RAM region.
- **[SLIMBOOK EVO15-A8 case (March 2026)](https://gist.github.com/gnespolino/81abd597153fd19aa2a039f66b8359a3)**:
  identical fingerprint (`GET_CAM_SUPPORTED=0`, `SET_NEW_CAM` timeout)
  on a different vendor's ASUS-sourced ITE EC firmware. Tested across
  same-distro live USB — reproduced identically. Recovery: only EC
  firmware reflash worked.
- **Kernel-side fix is already present**: Berg's PPM-change-info
  workaround commit `217504a055` (merged 5.10, backported to stable)
  is what would have routed around the missing `CAM_CHANGE` bit
  signal. Every NixOS kernel jorge has run includes it. Kernel swap
  cannot help — `linuxPackages_latest`, `_zen`, `_xanmod_latest` all
  resolve to 7.0.x and have identical UCSI behavior.
- **`fwupdmgr get-devices` confirms no separate EC firmware device**.
  ASUS bundles EC firmware inside the BIOS capsule. The only
  userspace-accessible write path that reaches the EC's policy region
  is a BIOS update (EZ Flash with the .CAP file from ASUS).

**Honest bottom line.** No combination of ACPI methods, WMI commands,
sysfs writes, kernel module reloads, or supported UCSI commands can
clear the wedge. BIOS update was the strongest single-shot escalation
on paper (mechanism + Slimbook precedent) — but **lewis 2026-05-21
BIOS .311 flash did NOT recover the wedge on first plug**. See the
2026-05-21 status update at the top of this file. The fix path is
genuinely open right now.

Cheap probes worth running before flashing (untested as of writing):

1. **Suspend → wait for `-70` UCSI errors in dmesg → fresh replug.**
   See `memory/xr-ec-altmode-suspend-replug-untested.md`. The 14:12
   working session yesterday had a lid-suspend 32 minutes prior; the
   resume produced two `ucsi_acpi GET_CONNECTOR_STATUS failed (-70)`
   errors. Today's wedged boot has had zero suspends. Cost ~30 sec.
2. **Plug glasses during BIOS POST, sit in BIOS 30-60s, then boot.**
   The EC's UCSI mailbox initializes during POST without Linux's
   `ucsi_acpi` driver issuing commands; possibly a different EC code
   path. Circumstantial evidence only. Cost ~5 min.
3. **Live USB Fedora 42 (kernel 6.12.x)** — diagnostic only,
   confirms or rules out NixOS-specific kernel state. Slimbook tested
   their same-distro live USB; nobody has tested a different-kernel
   live USB yet for this fingerprint. Cost ~30 min.

~~If 1-3 fail: BIOS update to 311 is the recommended next step.~~
**Done 2026-05-21 — BIOS 311 flash succeeded, wedge unchanged.**
See top-of-file status update for what's still on the table.

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
