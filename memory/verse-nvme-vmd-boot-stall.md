---
type: project
title: verse boots ~30s slow — Intel VMD + Micron NVMe I/O timeout in initrd
created: 2026-08-21
---

# The 30-second underscore-on-Catppuccin boot stall (verse)

**Symptom:** After POST, verse sits on a solid Catppuccin-base background with a single `_`
in the top-left corner for ~35s before SDDM appears.

The background is *not* a hang or a crash — `system/lib/device/intel/default.nix` ships
`vt.default_red/grn/blu` on the kernel cmdline (Catppuccin Mocha `#1e1e2e`), so the bare
kernel VT is themed. The `_` is just the VT cursor on an empty console. **Do not chase this
as a Hyprland, SDDM, or display-manager problem** — `display-manager.service` activates at
38.2s monotonic, only ~5s into userspace.

## Root cause

`systemd-analyze` splits as: firmware 4.7s + loader 5.7s + kernel 0.65s + **initrd 32.7s** +
userspace 69.4s. The initrd figure is a single stall, not accumulated unit time
(`systemd-analyze blame` shows <1s of initrd units):

```
>>> GAP 30.2s ends 32.36s : nvme nvme0: I/O tag 64 (4040) QID 3 timeout, completion polled
```

30s is the nvme driver's default I/O timeout. Present in 3 of the last 5 boots.

**Intel VMD (Volume Management Device / Intel RST) is enabled in BIOS.** Confirmation — the
drive is remapped into a synthetic PCI domain instead of `0000:`:

- `0000:00:0e.0 RAID bus controller: Intel Core Ultra 200H/200V Series Processors VMD [8086:7d0b]`
- `10000:e0:06.0 System peripheral: Intel RST VMD Managed Controller [8086:09ab]`
- nvme path: `/pci0000:00/0000:00:0e.0/pci10000:e0/10000:e0:06.2/10000:e1:00.0`
- `vmd` module loaded

Drive is Micron 2450 `MTFDKBA1T0QFM-1BD1AABGB`, firmware `V3MA101`.

Near-identical report on an ASUS Zenbook 14 UX3405CA + Micron `MTFDKBA1T0QGN`:
<https://discussion.fedoraproject.org/t/nvme-i-o-timeouts-and-slow-boot-on-asus-zenbook-with-micron-mtfdkba1t0qgn/187890>
— 76s boot → ~16s after **disabling Intel VMD in UEFI**. Same `QID timeout, completion polled`
signature, same "drive at a non-standard bus address" tell.

## Disabling VMD is safe on verse (verified 2026-08-21, before any change)

- `system/hosts/verse/hardware-configuration.nix:11` already lists **both** `"vmd"` and
  `"nvme"` in `boot.initrd.availableKernelModules` → initrd boots the drive either way.
- Every filesystem + swap uses `/dev/disk/by-uuid/...`. UUIDs live in the filesystem
  superblock, so PCI re-enumeration (`10000:e1:00.0` → some `0000:xx:00.0`) does not
  affect them.
- Nothing under `system/` hardcodes the PCI address or the `nvme0n1` node
  (`grep -rn "10000:\|e1:00.0\|nvme0n1" system/ --include=*.nix` → empty).

Only a BIOS change can fix this; it is not expressible in the Nix config. See
[[asus-zenbook-bios-flash-quirks]] for how to reach the ASUS firmware UI on this model.

Kernel-param fallbacks if BIOS VMD cannot be turned off (untested here):
`nvme_core.default_ps_max_latency_us=0` (kill APST deep states), `pcie_aspm=off`.
Note `system/lib/device/intel/default.nix:17` currently forces `pcie_aspm=force`, and
FIXES.md records that flag delivered "marginal improvement at best" for battery.

## The SECOND stall — 60s, and it DOES block the desktop

Corrected 2026-08-25. An earlier version of this note said this one does not delay login,
reasoning from `display-manager.service` activating at 7.6s. **That reasoning was wrong.**

`NetworkManager-wait-online.service` always burns 60s and fails — because of a **deadlock
this repo created itself**, not because the network is slow (wpa_supplicant logs
`CTRL-EVENT-CONNECTED` at **10.4s**).

`system/hosts/verse/data-saver.nix` is an NM dispatcher script that ran a *blocking*
`systemctl start tailscaled.service` on every `up` event. `tailscaled.service` is ordered
`After=NetworkManager-wait-online.service`, and NM does not report startup complete until
its dispatchers finish:

```
dispatcher -> tailscaled -> NM-wait-online -> NM startup complete -> dispatcher
```

Only the 60s timeout broke it. Decisive evidence: `NetworkManager-dispatcher.service:
Consumed 211ms CPU time over 1min 11.914s wall clock` (blocked, not busy) and
`tailscaled.service` activating at 68.1s, exactly when NM-wait-online gave up.
Fixed with `systemctl --no-block start` (commit `cdf3703`).

**Falsified theory — do not repeat:** the wifi-p2p device `p2p-dev-wlo1` sits at
`disconnected` with NM at `STARTUP=started`, which looks like the blocker. It is not.
A live `nm-online -s -t 5` returns **0 in 58ms**; per `nm-online(1)`, *"After startup has
completed, nm-online -s will just return immediately"* — so a live run can never be
evidence about boot-time behaviour.

**Rule:** never call a blocking `systemctl start` from an NM dispatcher script.

SDDM does start early — but it launches **uwsm**, and uwsm blocks on `graphical.target`:

```
[ 8.58s] uwsm: graphical.target is queued for start, waiting for 60s...
[68.65s] uwsm: Timed out.  System has not reached graphical.target.
[73.69s] uwsm: Selected compositor ID: hyprland.desktop
```

Chain: `NetworkManager-wait-online` → `network-online.target` → `docker.service` →
`multi-user.target` → `graphical.target` → uwsm releases → Hyprland.
`graphical.target` landed at 69.1s; uwsm gave up at 68.65s — missed by ~0.5s, so the whole
60s applied.

**Rule: when the greeter appears but the desktop does not, look at the session launcher
(uwsm), not just `display-manager.service`.**

Fixed in `system/hosts/verse/networking.nix` with
`systemd.services.NetworkManager-wait-online.enable = false;` (commit `017eddf`).
Only `docker.service` and `nixos-upgrade.service` want `network-online.target` here.

## Windows dual-boot blocks the VMD fix

verse dual-boots Windows (`nvme0n1p4`, 415G NTFS + a Microsoft reserved partition).
Windows was installed with VMD on, so Intel RST is a boot-critical driver and Windows
fails to boot with VMD disabled. Turning VMD off to kill stall 1 therefore breaks Windows
unless Windows is first re-pointed at the inbox NVMe driver — the standard one-time
safe-boot cycle (`bcdedit /set {current} safeboot minimal` → reboot → change BIOS → boot
safe mode → `bcdedit /deletevalue {current} safeboot`). Untested here.

Measured with VMD **off**: initrd 32.7s → 2.4s, no nvme timeout, nvme at `0000:01:00.0`.
So the 30s saving is real — it just costs the Windows install until that dance is done.
