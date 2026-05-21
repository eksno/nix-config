---
type: reference
title: ASUS Zenbook UX3405MA BIOS flash via USB — verified procedure quirks
created: 2026-05-21
---

Stable facts captured after Jorge's 301→311 flash attempt on lewis
(ASUS Zenbook 14 UX3405MA, Intel Meteor Lake-P). Useful next time
this model needs a BIOS update.

## Tool name (NOT what most guides say)

On Zenbook **laptops** the local USB flash utility is called:

> **ASUS Firmware Update**

NOT "EZ Flash" or "EZ Flash 3 Utility" — those names appear in
ASUS motherboard guides only. Per ASUS FAQ 1054166: the `Tool` tab
guides cover motherboards, not Zenbook laptops. Zenbook BIOS has
tabs `Main / Advanced / Boot / Security / Save & Exit` — **no Tool
tab**.

Inside `ASUS Firmware Update`, choose **`via Storage Device(s)`**
(local USB) rather than `via Internet` (cloud).

## File preparation

- Download the **"BIOS for ASUS EZ Flash Utility"** zip from ASUS
  support page (NOT "BIOS Update (Windows)" — that's a `.exe`
  installer, won't be visible in the BIOS picker).
- File like `UX3405MAAS.311` lives at FAT32 **root** (not in a
  folder).
- **Do NOT rename** the file to `.CAP`. That's the motherboard
  BIOSRenamer / Flashback workflow — irrelevant on Zenbook laptops.
  EZ Flash matches by model prefix.
- File header should contain `AMIPFATc` / `AMI_BIOS_GUARD_FLASH_CONFIGURATIONS`
  strings (verify with `head -c 256 <file> | strings`); a 38 MB
  single file is consistent with a correct EZ Flash image.

## USB port

UX3405MA has 2× USB-C TB4 + 1× USB-A. **Plug the stick into the
USB-A port.** Meteor Lake Zenbooks have a documented pre-boot
enumeration quirk where USB-C storage often doesn't show up in
the BIOS file picker. USB-A is the reliable path.

## No BIOS Flashback button

UX3405MA does NOT have a Flashback button. That feature is
motherboard/desktop-only per ASUS FAQ 1038568 / 1053582. There is
no PCB-level recovery path — if a flash fails mid-write, ASUS
service center is the answer.

## Confirming a flash succeeded

```bash
cat /sys/class/dmi/id/bios_version   # e.g. UX3405MA.311
cat /sys/class/dmi/id/bios_date      # e.g. 06/06/2025
```

## What flashing 311 does NOT necessarily fix

The escalation path in `xr-lewis-ec-refuses-altmode.md` cited
the Slimbook precedent as "BIOS reflash recovers the EC altmode
wedge". On lewis 2026-05-21 the 301→311 flash **completed
cleanly** but the EC altmode wedge fingerprint was **identical
on first plug post-flash** — `accessory_mode=none`, kernel saw
only USB HID enumeration on plug, zero typec/UCSI events. So
"BIOS update recovers the wedge" is now provisionally falsified
for *this specific bug* on UX3405MA, at least on first attempt.
See that memory's 2026-05-21 section for current state.

## Sources

- [ASUS FAQ 1008859 — Update BIOS with ASUS Firmware Update / EZ Flash](https://www.asus.com/support/faq/1008859/)
- [UX3405MA BIOS downloads page](https://www.asus.com/supportonly/ux3405ma/helpdesk_bios/)
- [ASUS FAQ 1054166 — EZ Flash Introduction (motherboard-only scope)](https://www.asus.com/uk/support/faq/1054166/)
- [ASUS FAQ 1038568 — USB BIOS FlashBack (motherboard/desktop only)](https://www.asus.com/support/faq/1038568/)
