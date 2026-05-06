# Memory index

<!-- One line per topic file under each heading. Format:
     - [Title](file.md) — one-line hook -->

## user

(none yet — global ~/.claude/.../memory has user-level facts)

## project

### xr/ subsystem

- [XR stack overview](xr-stack-overview.md) — entry point: packages, modules, data flow, what does what
- [Mesa anv direct-mode SURFACE_LOST](xr-mesa-anv-display-gap.md) — surface+swapchain create succeed, first present fails. Misdiagnosed earlier as "missing VK_KHR_display device funcs" — that was wrong. Check before suggesting fixes.
- [wlroots leasing rules](xr-wlroots-leasing-rules.md) — only EDID-non-desktop connectors get advertised via wp-drm-lease-v1. `hyprctl monitor disable` does NOT make a connector leasable.
- [Rayneo hardware facts](xr-rayneo-hardware.md) — Air 4 Pro 1bbb:af50, DP-2 on lewis, cable-quality gotcha, USB ACL boot-race fix
- [EDID override module](xr-edid-override.md) — how `glasses-edid/` flips non_desktop=1, how to regenerate the patched blob, per-host caveats
- [Monado/launcher IPC quirks](xr-monado-ipc-quirks.md) — pollable stdin, persistent pipe, XR_RUNTIME_JSON propagation. Ignore at your peril.
- [Offline OSS source corpus](xr-research-corpus.md) — `.research/` (~1.8 GB, gitignored): mesa, monado, kernel DRM, Hyprland, wlroots, etc. Grep here before re-fetching.
- [Mesa wsi_display tracing is disabled](xr-mesa-wsi-debug-disabled.md) — `MESA_VK_WSI_DEBUG=display` is a no-op; the macro is `#if 0`'d at `wsi_common_display.c:99-105`.
- [wayvr GPU/DMA-BUF capture segfault](xr-wayvr-gpu-capture-segfault.md) — wayvr crashes at `screen/backend.rs:200` after FOCUSED; atlas-grow patch ruled out, DMA-BUF import on anv suspected. Read before re-debugging.

### nixos build + host model

- [NixOS rebuild flow](nixos-rebuild-flow.md) — `update.sh` quirks (`git add .` before flake), `--impure`, dotfile activation script, fast-iteration without flake bumps
- [Host context detection protocol](nixos-host-context-protocol.md) — `fastfetch` first (mandatory), then host/user → directory mapping
- [lewis host profile](lewis-host-profile.md) — Intel Arc, Hyprland primary, battery cap 85%, primary dev box

### upstream constraints

- [Breezy productivity-tier paywall](breezy-license-paywall.md) — why `breezy-gnome` was abandoned; what stays installed as fallback

## feedback

- [Verify before recommending from memory](process-verify-before-recommend.md) — memory says "X existed when written," not "X exists now." Grep/read first.
- [Don't SIGKILL DRM-grabbing processes](xr-shutdown-discipline.md) — SIGINT + wait, never SIGKILL. Killing mid-frame trashes Hyprland's monitor list.

## reference

- [XR debug commands](xr-debug-commands.md) — drm_info paths, vulkaninfo greps, edid-decode, monado log location, hyprctl probes
- [xr-driver control IPC](xr-driver-control-ipc.md) — `/dev/shm/xr_driver_control` keys (sbs_mode=enable/disable, recenter_screen=true), state file, validation gotchas
