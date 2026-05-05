---
type: project
title: Host context detection — fastfetch first, then directory mapping
created: 2026-05-06
---

Mandatory protocol for any task in this repo. Already in CLAUDE.md but
restated here because skipping it is the most common cause of editing
the wrong host's config.

## Step 1: fastfetch

```bash
fastfetch --logo none --show-errors
```

Gives host, user, OS, kernel, uptime, DE/WM, theme. Errors included
because "No DE found" / "No themes found" are themselves useful signals.

**Do NOT** substitute `echo $HOSTNAME $USER` as a shortcut. The only
acceptable fall-back is when fastfetch literally fails to run (command
not found, non-zero exit, empty output).

## Step 2: directory mapping

| Host | User | Desktop | Notable |
|---|---|---|---|
| `verse` | `eksno` | Hyprland (Intel) | Catppuccin, Phonetic, battery 80% |
| `lewis` | `jorge` | Hyprland (Intel) | Catppuccin, Phonetic, battery 85%, **XR work** |
| `chuu` | `nabi` | Hyprland | Steam |
| `lappy` | `teto` | Hyprland | Steam, ZSA, Docker |
| `chrono` | `teto` | Minimal | Steam, ZSA, Docker |
| `ace` | `biwas` | GNOME/X11 (NVIDIA) | Steam, Docker, DroidCam, ADB |

→ edit `system/hosts/<host>/` and `system/users/<user>/` accordingly.

Other dirs exist (`system/users/lucy`, `system/users/tetochrono`,
`system/hosts/tetomini`) but are NOT wired into `flake.nix`. Don't edit
them assuming they're live.

## Scope rule

Don't edit configs for other host/user pairs unless explicitly asked.
Cross-host changes (e.g. shared modules in `system/lib/`) are fine, but
flag them — they affect every host that imports the module.

## Why the strict protocol

Past sessions have edited `verse`'s files thinking they were on `lewis`,
or vice versa. The cost of one extra fastfetch call is trivial; the
cost of fixing a wrong-host edit (debug, revert, redo) is high.
