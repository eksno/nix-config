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

## Unrelated second stall (does NOT delay login)

`NetworkManager-wait-online.service` burns 60s then **fails** (`nm-online -s -q`, exit 1).
Cause: `p2p-dev-wlo1` (wifi-p2p) never leaves `disconnected`, so NM never reports startup
complete. It gates `network-online.target` → `docker.service` → `multi-user.target` →
`graphical.target` (100.2s). Because `display-manager.service` is only
`After=plymouth-quit.service systemd-user-sessions.service`, SDDM does not wait on it.

Related: [[nixos-rebuild-flow]], [[asus-zenbook-bios-flash-quirks]]
