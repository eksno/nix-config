# Memory index

<!-- One line per topic file under each heading. Format:
     - [Title](file.md) — one-line hook -->

## user

(none yet — global ~/.claude/.../memory has user-level facts)

## project

### xr/ subsystem

- [XR stack overview](xr-stack-overview.md) — entry point: packages, modules, data flow, what does what
- [Mesa anv display-plane gap on Intel Arc](xr-mesa-anv-display-gap.md) — VK_KHR_display advertised but not implemented; blocks direct-mode VR. Verify before retrying any direct-render path on lewis.
- [wlroots leasing rules](xr-wlroots-leasing-rules.md) — only EDID-non-desktop connectors get advertised via wp-drm-lease-v1. `hyprctl monitor disable` does NOT make a connector leasable.
- [Rayneo hardware facts](xr-rayneo-hardware.md) — Air 4 Pro 1bbb:af50, DP-2 on lewis, cable-quality gotcha, USB ACL boot-race fix
- [EDID override module](xr-edid-override.md) — how `glasses-edid/` flips non_desktop=1, how to regenerate the patched blob, per-host caveats
- [Monado/launcher IPC quirks](xr-monado-ipc-quirks.md) — pollable stdin, persistent pipe, XR_RUNTIME_JSON propagation. Ignore at your peril.

### nixos build + host model

- [NixOS rebuild flow](nixos-rebuild-flow.md) — `update.sh` quirks (`git add .` before flake), `--impure`, dotfile activation script, fast-iteration without flake bumps
- [Host context detection protocol](nixos-host-context-protocol.md) — `fastfetch` first (mandatory), then host/user → directory mapping
- [lewis host profile](lewis-host-profile.md) — Intel Arc, Hyprland primary, battery cap 85%, primary dev box

### upstream constraints

- [Breezy productivity-tier paywall](breezy-license-paywall.md) — why `breezy-gnome` was abandoned; what stays installed as fallback

## feedback

- [Stop-the-loop rule](process-stop-the-loop.md) — after 3 failed attempts at the same root-cause hypothesis, halt and ask. Don't try a 4th variation.
- [Verify before recommending from memory](process-verify-before-recommend.md) — memory says "X existed when written," not "X exists now." Grep/read first.
- [Don't SIGKILL DRM-grabbing processes](xr-shutdown-discipline.md) — SIGINT + wait, never SIGKILL. Killing mid-frame trashes Hyprland's monitor list.
- [XR loop history](xr-loop-history.md) — concrete incidents where I went in circles in xr/, with the lesson from each. Read before starting any xr/ debugging session.

## reference

- [XR debug commands](xr-debug-commands.md) — drm_info paths, vulkaninfo greps, edid-decode, monado log location, hyprctl probes
