---
type: project
title: Writing + verifying OS images to USB on verse
created: 2026-09-05
---

# Writing + verifying OS images to USB on verse

## `dd` progress lies without `oflag=direct`

Without it, `dd` reports the speed of filling the page cache, not the device.
A stick that "wrote at 4 MB/s" had 4.5 GB of dirty pages queued and was actually
draining at ~1 MB/s — over an hour of hidden writeback after `dd` "finished".

Use: `unzip -p img.zip | dd of=/dev/sdX bs=4M iflag=fullblock oflag=direct conv=fsync status=progress`

`iflag=fullblock` is required when the input is a pipe, or direct I/O gets short reads.

Check for hidden writeback with `grep -E '^(Dirty|Writeback):' /proc/meminfo`.
To abandon a slow write without waiting for the flush, detach the device — this
drops its dirty pages instead of grinding them out:
`echo 1 | sudo tee /sys/block/sdX/device/delete` (needs a physical replug after).

## Hash mismatch after writing is EXPECTED — it's udisks automount, not corruption

Do not conclude the write failed. After the partition table appears (`partprobe`,
or just plugging in), **udisks2 auto-mounts every mountable partition**, and
mounting ext4/vfat writes metadata. Re-reading the device then hashes differently
from the source image.

Diagnosis that distinguishes benign automount from real corruption:
1. Chunk-compare rather than whole-file hash — a bad flash differs in many
   chunks, automount differs in 2-3 tight clusters.
2. Map differing byte offsets onto `lsblk -b -o NAME,START,SIZE,PARTLABEL`.
   Benign = only the *writable* partitions (ChromeOS: `STATE`, `OEM`,
   `EFI-SYSTEM`). `ROOT-A` / `KERN-A` must be byte-identical.
3. Confirm at the ext4 superblock (partition offset 1024): `s_mtime` (+0x2C),
   `s_wtime` (+0x30), `s_mnt_count` (+0x34). An incremented mount count and
   today's timestamp = mounted, not corrupted.

`wipefs -n /dev/sdX` (dry run) is the truth for on-disk signatures; `lsblk`
FSTYPE can show a stale cached label from the *previous* image after rewrite.

## Spotting a junk USB stick before trusting it

`udevadm info -q property -n /dev/sdX`. Placeholder descriptors are the tell:
`ID_VENDOR=VendorCo`, `ID_MODEL=ProductCode`, `ID_VENDOR_ID=ffff` — an
unbranded controller, often with faked capacity. Real drives carry a registered
vendor ID (e.g. Transcend/JetFlash = `8564`).

Cheap non-destructive health check before committing to a long write:
- link speed: `cat /sys/devices/.../usbN/N-1/speed` (5000 = USB 3.0)
- read rate: `dd if=/dev/sdX of=/dev/null bs=4M count=150 iflag=direct`

## `pkill -f` kills the calling shell

`pkill -f "somescript.sh"` inside a Bash tool call matches the tool's own
command line (the pattern is in it) and aborts the call with exit 144, so the
rest of the compound command never runs. Kill by PID from `ps -eo pid,args`
instead.
