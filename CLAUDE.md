# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Multi-user, multi-host NixOS flake configuration ("Chronoverse"). Tracks nixpkgs unstable. No home-manager -- all user configs are system-level Nix options and dotfiles symlinked from the repo.

**Important:** Check `$HOSTNAME` and `$USER` on the current machine to determine which NixOS configuration is active. Use the host/user table below to find the correct `system/hosts/` and `system/users/` directories to modify -- do not edit configs for other host/user pairs unless asked.

## Commands

| Command | Purpose |
|---------|---------|
| `./update.sh` | Rebuild system: stages files, updates flake lock, runs `nixos-rebuild switch --flake "./#$HOSTNAME" --impure` |
| `./update.sh reconfigure` | Rebuild with manual host selection (use when hostname is "nixos" or changing hosts) |
| `./update.sh symlink` | Rebuild and re-symlink dotfiles |
| `./symlink.sh` | Create dotfile symlinks from `dotfiles/` to `~/.config/` and `~/.local/share/` |
| `./symlink.sh remove` | Remove all dotfile symlinks |
| `./hypr.sh` | Regenerate `hyprland.conf` sourcing user/host configs, then `hyprctl reload` |
| `./gc.sh` | Garbage collect old generations (keeps last 10), then runs update.sh |
| `./install.sh` | First-time setup: backs up `/etc/nixos`, symlinks repo there |

All scripts must be run as a normal user (not with sudo directly); they elevate internally as needed. `update.sh` does `git add .` before rebuild because Nix flakes only see staged files.

## Architecture

```
flake.nix                       # Defines 5 NixOS configurations (host + user pairs)
system/
  hosts/{hostname}/             # Per-machine: hardware-configuration.nix, boot.nix, networking.nix
  users/{username}/             # Per-user: packages, locale, theme, dev tools
  lib/                          # Shared reusable modules
    system.nix                  #   Flakes, GC, auto-upgrade, stateVersion
    fish.nix                    #   Fish shell + plugins (done, fzf-fish, forgit)
    fonts.nix                   #   Font packages
    desktop/default.nix         #   Pipewire, CUPS, GNOME Keyring, Catppuccin theming
    desktop/wayland/            #   Hyprland + SDDM
    desktop/x11/               #   GNOME on X11
    device/nvidia/              #   NVIDIA driver config
    device/intel/               #   Intel graphics + media drivers
dotfiles/                       # App configs symlinked to ~/.config/
  hypr/{hosts,users,shared}/    #   Hyprland: per-host and per-user, composed by hypr.sh
  nvim/, fish/, kitty/, tmux/,  #   Other app configs
  waybar/, mako/, tofi/, eww/
npins/                          # Pinned deps (catppuccin/nix) outside flake inputs
```

### Flake structure

Each NixOS configuration composes exactly two modules: a user and a host.

```nix
nixosConfigurations.verse = nixpkgs.lib.nixosSystem {
  modules = [ ./system/users/eksno  ./system/hosts/verse ];
};
```

| Host | User | Desktop | GPU |
|------|------|---------|-----|
| `verse` | `eksno` | Hyprland | Intel |
| `chuu` | `nabi` | Hyprland | - |
| `lappy` | `teto` | Hyprland | - |
| `chrono` | `teto` | Minimal | - |
| `ace` | `biwas` | GNOME/X11 | NVIDIA |

The `verse` configuration additionally imports the Catppuccin NixOS module from npins.

### Key patterns

- **Packages go in** `system/users/{user}/programs/default.nix` via `environment.systemPackages`.
- **Shared modules** in `system/lib/` are imported by user or host configs as needed (e.g., `../../lib/desktop/wayland/hyprland`).
- **Hyprland config** is composed at runtime: `hypr.sh` writes a `hyprland.conf` that sources `~/.config/hypr/users/$USER/default.conf` and `~/.config/hypr/hosts/$HOSTNAME/default.conf`.
- **Dotfile changes** take effect immediately (they're symlinks), except Hyprland which needs `./hypr.sh` or `hyprctl reload`.
- **System changes** (anything under `system/`) require `./update.sh` to apply.
- **allowUnfree** is enabled globally. `--impure` flag is used on rebuild.
- **npins** pins `catppuccin/nix` separately from flake inputs; imported via `import ./npins` in flake.nix.

## Adding a new host

1. Create `system/hosts/{hostname}/` with `default.nix` and `hardware-configuration.nix`
2. Create or reuse a user config under `system/users/{username}/`
3. Add the configuration to `flake.nix` `nixosConfigurations`
4. Optionally add Hyprland configs in `dotfiles/hypr/hosts/{hostname}/`
5. Run `./update.sh reconfigure`
