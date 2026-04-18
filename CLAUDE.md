# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Multi-user, multi-host NixOS flake configuration ("Chronoverse"). Tracks nixpkgs unstable. No home-manager -- all user configs are system-level Nix options and dotfiles symlinked from the repo.

**Important:** Determine which NixOS configuration is active on the current machine before editing. Prefer `fastfetch --logo none --show-errors` — it returns host, user, OS, kernel, uptime, DE/WM, theme, and much more in one call (errors included, since "No DE found" / "No themes found" are themselves useful signals about the system). If fastfetch isn't available or fails, fall back to `echo $HOSTNAME $USER`. Then use the host/user table below to find the correct `system/hosts/` and `system/users/` directories to modify -- do not edit configs for other host/user pairs unless asked.

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
| `./nvidia-offload.sh` | Wrapper to run a command with NVIDIA GPU offload env vars |

All scripts must be run as a normal user (not with sudo directly); they elevate internally as needed. `update.sh` does `git add .` before rebuild because Nix flakes only see staged files.

## Architecture

```
flake.nix                       # Defines 6 NixOS configurations (host + user pairs)
system/
  hosts/{hostname}/             # Per-machine: hardware-configuration.nix, boot.nix, networking.nix
  users/{username}/             # Per-user: packages, locale, theme, dev tools
  lib/                          # Shared reusable modules
    system.nix                  #   Flakes, GC, auto-upgrade, stateVersion (25.05)
    fish.nix                    #   Fish shell + plugins (done, fzf-fish, forgit)
    fonts.nix                   #   Font packages
    power-mode/                 #   CPU/GPU frequency scaling + battery management
    desktop/default.nix         #   Pipewire, CUPS, GNOME Keyring, Catppuccin theming
    desktop/wayland/            #   Wayland env vars + wl-clipboard/wl-screenrec
    desktop/wayland/hyprland/   #   Hyprland + SDDM display manager
    desktop/x11/               #   X11 base (xclip)
    desktop/x11/gnome/         #   GDM + GNOME desktop
    device/nvidia/              #   NVIDIA driver config (beta, open kernel module)
    device/intel/               #   Intel graphics, media drivers, compute runtime
dotfiles/                       # App configs symlinked to ~/.config/
  default/                      #   Default configs for all users
    hypr/{hosts,users,shared}/  #     Hyprland: per-host and per-user, composed by hypr.sh
    nvim/, fish/, kitty/, tmux/ #     Other app configs
    waybar/, mako/, tofi/, eww/
    btop/, icons/               #     Btop themes, icon themes
    xdg-desktop-portal/         #     XDG portal configs
  users/{username}/             #   Per-user dotfile overrides (shadow default/)
npins/                          # Pinned deps outside flake inputs
patches/                        # Patches (e.g., waybar XDG output fallback)
certs/                          # Local CA certificates (caddy)
.scratch/                       # Gitignored: Claude artifacts, debug logs, test outputs
```

### Flake structure

Each NixOS configuration composes a user and a host module. Some additionally import the Catppuccin NixOS module from npins and the Phonetic overlay.

```nix
nixosConfigurations.verse = nixpkgs.lib.nixosSystem {
  modules = [
    (sources.catppuccin + "/modules/nixos")
    { nixpkgs.overlays = [ inputs.phonetic.overlays.default ]; }
    ./system/users/eksno
    ./system/hosts/verse
  ];
};
```

**Flake inputs:** `nixpkgs` (unstable), `zen-browser`, `phonetic`

| Host | User | Desktop | GPU | Extras |
|------|------|---------|-----|--------|
| `verse` | `eksno` | Hyprland | Intel | Catppuccin, Phonetic, power-mode, battery cap 80% |
| `lewis` | `jorge` | Hyprland | Intel | Catppuccin, Phonetic, power-mode, battery cap 85%, Caddy |
| `chuu` | `nabi` | Hyprland | - | Steam |
| `lappy` | `teto` | Hyprland | - | Steam, ZSA keyboard, Docker |
| `chrono` | `teto` | Minimal | - | Steam, ZSA keyboard, Docker |
| `ace` | `biwas` | GNOME/X11 | NVIDIA | Steam, Docker, DroidCam, ADB |

Additional user directories exist (`lucy`, `tetochrono`) and host directories (`tetomini`) but are not wired into `flake.nix` configurations.

### Key patterns

- **Packages go in** `system/users/{user}/programs/default.nix` via `environment.systemPackages`.
- **Dev tools** for `eksno` and `jorge` are in `system/users/{user}/dev/` (Python, Nixpacks, etc.).
- **Shared modules** in `system/lib/` are imported by user or host configs as needed (e.g., `../../lib/desktop/wayland/hyprland`).
- **Module import chain:** `hyprland/ -> wayland/ -> desktop/ -> {system.nix, fish.nix, fonts.nix}`. Each level imports its parent.
- **Hyprland config** is composed at runtime: `hypr.sh` writes a `hyprland.conf` that sources `~/.config/hypr/users/$USER/default.conf` and `~/.config/hypr/hosts/$HOSTNAME/default.conf`.
- **Dotfile symlinks:** `symlink.sh` links shared configs to `~/.config/` and merges per-user overrides from `dotfiles/users/{username}/` (per-user files take precedence).
- **Dotfile changes** take effect immediately (they're symlinks), except Hyprland which needs `./hypr.sh` or `hyprctl reload`.
- **System changes** (anything under `system/`) require `./update.sh` to apply.
- **allowUnfree** is enabled globally. `--impure` flag is used on rebuild.
- **npins** pins `catppuccin/nix` (v25.05) separately from flake inputs; imported via `import ./npins` in flake.nix.

## Scratch directory

`.scratch/` is a gitignored directory for Claude to store temporary artifacts — test outputs, debug logs, exploration notes, diffs, etc. Nothing in `.scratch/` is committed. Use it freely during debugging and investigation.

## MANDATORY: Auto-Commit After Every Change

**ALWAYS commit immediately after completing each logical code change. No exceptions. Never leave changes uncommitted — every edit must be followed by a commit before responding to the user or moving to the next task.**

- Use scoped conventional commits: `feat(scope):`, `fix(scope):`, etc.
- If a task involves multiple distinct steps (e.g., refactor + new feature + bug fix), each step gets its own commit before moving to the next
- Do not batch unrelated changes into a single commit
- Do not wait for the user to ask you to commit — committing is automatic and mandatory after every change

## MANDATORY: Log Every Fix to FIXES.md

**Whenever you complete a fix for a non-trivial issue (bug, broken behavior, misconfiguration, regression), append an entry to `FIXES.md` in the same commit as the fix.** NixOS is finicky and remembering past issues prevents repeating debugging work.

**Before debugging any new issue, grep `FIXES.md` first** for related symptoms, file paths, or tools — past investigations often contain the answer or rule out dead ends.

Newest entries go at the **top** of the file. Entry format:

    ## YYYY-MM-DD — short kebab-case title

    **Symptom:** what the user observed
    **Affected:** host/user, key files (use `path:line` format)
    **Root cause:** the underlying reason
    **Investigation:**
    1. step one — what was tried, what was learned
    2. step two — including dead ends and wrong assumptions
    3. ...
    **Fix:** what changed and where
    **Commit:** `<sha>` (fill in after committing)

- Log fixes only — not feature work, refactors, doc edits, or one-line typo corrections
- **Include dead ends and wrong turns** in the investigation; the failed paths are often the most useful part for future debugging
- Keep entries terse but complete — a future Claude (or Jorge) should be able to reproduce the diagnosis from the entry alone
- It's fine to update an entry's commit sha in a follow-up commit if needed

## Adding a new host

1. Create `system/hosts/{hostname}/` with `default.nix` and `hardware-configuration.nix`
2. Create or reuse a user config under `system/users/{username}/`
3. Add the configuration to `flake.nix` `nixosConfigurations`
4. Optionally add Hyprland configs in `dotfiles/hypr/hosts/{hostname}/`
5. Optionally add per-user dotfile overrides in `dotfiles/users/{username}/`
6. Run `./update.sh reconfigure`
