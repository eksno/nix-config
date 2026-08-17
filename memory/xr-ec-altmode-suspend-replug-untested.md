---
type: project
title: Untested hypothesis — post-suspend UCSI -70 errors may briefly clear EC altmode wedge if glasses are replugged immediately after
created: 2026-05-08
---

A temporal-diff sub-agent comparing lewis's last working DP altmode
session (2026-05-07 ~14:12) against the current wedged boot found
**one specific software-state difference** worth testing as a
non-flash recovery path.

## The observation

Working boot (boot `-6`, May 07 00:22-15:15 +07):

```
May 07 13:40:15 lewis kernel: Freezing user space processes  ← lid-close suspend
May 07 13:40:15 lewis kernel: Lid opened.                    ← already waking
May 07 13:40:15 lewis kernel: i915 ... GuC firmware ...      ← i915 re-init
May 07 13:40:23 lewis kernel: ucsi_acpi USBC000:00: GET_CONNECTOR_STATUS failed (-70)
May 07 13:40:23 lewis kernel: ucsi_acpi USBC000:00: GET_CONNECTOR_STATUS failed (-70)
...
May 07 14:12:07 lewis kernel: usb 3-2: New USB device ... idVendor=1bbb  ← working plug
```

The UCSI `-70 ETIMEDOUT` errors on resume are the kernel's signal
that the UCSI mailbox got re-synced with the EC post-resume. The
glasses were then plugged 32 minutes later and DP altmode negotiated
successfully.

The wedged boot has had zero lid-suspend events. The UCSI mailbox
was never re-synced from its wedged state during this boot.

## Why this is NOT obviously already in "what doesn't recover"

`memory/xr-lewis-ec-refuses-altmode.md` line 109 lists "`systemctl
suspend` + wake" as ineffective — but that test was done WITHOUT a
subsequent fresh glasses replug timed after the resume's `-70`
errors. The hypothesis here is that the specific sequence matters:
**resume → see -70 errors → THEN plug glasses fresh.** Replugging
*before* the resume completes its UCSI re-sync would not exercise
the same code path.

## How to test (non-destructive, ~30 sec)

Glasses unplugged. Lid closed. Wait 5 seconds. Lid open. Wait until
`dmesg | tail` shows the `GET_CONNECTOR_STATUS failed (-70)` lines.
THEN plug glasses fresh. Check:

```bash
stat -c%s /sys/class/drm/card1-DP-2/edid
# 256 = recovered (firmware EDID applied)
# 0   = still wedged
```

Also re-run the UCSI 5-command fingerprint from
`xr-lewis-ec-refuses-altmode.md`. If `GET_CAM_SUPPORTED` returns
nonzero, altmode genuinely re-armed.

## Caveats

- **Most likely doesn't work.** The deeper diagnosis in
  `xr-lewis-ec-refuses-altmode.md` (DSDT search, EC flash
  unreachability) suggests the lockout state is in EC firmware
  flash, untouched by S0ix suspend/resume. The temporal correlate
  may be coincidence — yesterday the wedge cleared during heavy
  testing, the suspend was 32 min before the working plug, and many
  other state transitions happened in between.
- **If it works once, it might not work twice** (same caveat as
  yesterday's recovery — cause unknown, not reliably reproducible).
- **The UCSI fingerprint might lie** even if visual recovery
  succeeds. See `LEARNINGS.md` "UCSI debugfs is NOT a reliable
  signal for actual altmode state" — i915 can negotiate DP
  independently. So always cross-check against `hyprctl monitors -j`
  and `/sys/class/drm/card1-DP-*/{status,edid}`.

## Apply

If the wedge re-occurs and you want to try a free recovery before
BIOS update, this is the cheapest specific test the diagnostic
dungeon yielded. Run it once or twice; if it doesn't work, escalate
to BIOS UX3405MA.301 → 311 per
`memory/xr-lewis-ec-refuses-altmode.md` "Where the lockout state
lives" section.
