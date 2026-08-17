---
type: project
title: lewis host profile (Jorge's primary dev box)
created: 2026-05-06
---

`lewis` is the primary host where most active development happens.
User: `jorge`.

## Hardware

- **GPU**: Intel Arc (anv driver). No NVIDIA. Implications:
  - `nvidia-offload.sh` doesn't apply.
  - **Mesa anv display-plane gap is hit on this host** — see
    [Mesa anv display gap](xr-mesa-anv-display-gap.md). This is the
    blocker for the XR direct-render path.
- **Display**: Built-in laptop panel (HDMI-A-1 in Hyprland config) +
  Rayneo glasses on DP-2 when plugged.
- **Battery cap**: 85% (set by `system/lib/power-mode/`). Don't change
  without asking — Jorge sets per-host caps deliberately.

## Software stack

- **Compositor**: Hyprland (Wayland, wlroots-based). Primary, not
  fallback — there's no working X11 session on this host.
- **Login manager**: SDDM.
- **Theme**: Catppuccin (system-wide via `(sources.catppuccin)/modules/nixos`).
- **Overlay**: Phonetic (custom phonetic overlay from flake input).
- **HTTPS**: Caddy with local CA (`certs/`). lewis-only.
- **Shell**: Fish (with done, fzf-fish, forgit plugins).

## XR-related modules imported on this host

(In `system/hosts/lewis/default.nix`)

- `system/lib/xr/glasses-edid` — non-desktop EDID + USB ACL fix
- (Indirectly via `system/users/jorge/dev/`) — `monado-rayneo`,
  `breezy-hyprland`, `xr-driver`

## What's NOT on lewis (deliberately)

- No GNOME — see [Breezy paywall](breezy-license-paywall.md). The
  `breezy-gnome` machinery is built but only reachable via SDDM
  fallback session.
- No Docker — Jorge runs Docker on `lappy`/`chrono`/`ace`, not lewis.
- No Steam — lewis is dev box, not gaming box.

## Per-user dotfile overrides

`dotfiles/users/jorge/` shadows `dotfiles/default/` for jorge's view
on lewis (and any other host where jorge runs). E.g. monitor config at
`dotfiles/users/jorge/default/monitor.conf` defines lewis's baseline:

```
monitor = HDMI-A-1, 1920x1080@120, auto, 1
monitor = , preferred, auto, 1, mirror, HDMI-A-1
```

The `,` (empty desc) wildcard rule mirrors any additional connected
output (incl. glasses pre-EDID-override). With override active, glasses
don't appear in Hyprland at all.
