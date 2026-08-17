---
type: reference
title: NixOS rebuild flow — quirks and fast iteration
created: 2026-05-06
---

This repo's rebuild lifecycle is non-standard in a few ways. Knowing
them prevents debugging "why didn't my change apply" questions.

## `./update.sh` flow

```
git add .                    # Nix flakes only see staged files
nix flake update             # bumps flake.lock
nixos-rebuild switch --flake "./#$HOSTNAME" --impure
# system.activationScripts.dotfiles deploys symlinks during switch
```

Three things to remember:

1. **Unstaged files are invisible to nix**. If a Nix module references a
   file you just created and didn't `git add`, the build will fail with
   "file not found" even though `ls` shows it. `update.sh` does the
   `git add .` for you. If you call `nixos-rebuild` directly, do it
   yourself.
2. **`--impure` is required**. Some modules read `$HOSTNAME` or other
   env. Don't strip the flag.
3. **Dotfiles activate on every rebuild**. Adding a new dotfile to the
   repo requires a rebuild to create the symlink. EDITING an existing
   dotfile takes effect immediately (it's a symlink to the repo file).

## `./update.sh reconfigure`

Use when `$HOSTNAME` is unset, set to "nixos", or you're rebuilding for
a different host than the one detected. Prompts for host selection.

## `./update.sh nix` vs bare `./update.sh`

Same thing. The `nix` arg is explicit. Other args (e.g. `reconfigure`)
change behavior.

## Fast iteration without flake bumps

For tight inner loops (editing a single Nix file, no new flake input):

```bash
./update-without-update.sh   # skips `nix flake update`
```

Saves ~30s per cycle. Use this when iterating on launcher scripts or
module config and you know no upstream needs refreshing.

## Hyprland reload

After any dotfile change touching `dotfiles/default/hypr/` or
`dotfiles/users/jorge/hypr/`:

```bash
hyprctl reload
```

The activation script regenerates `~/.config/hypr/hyprland.conf` (which
sources host + user partials), but Hyprland doesn't auto-reload. The
global memory rule says: chain `&& hyprctl reload` to rebuild commands
on Hyprland hosts. (`lewis`, `verse`, `chuu`, `lappy` are Hyprland.)

## Garbage collection

```bash
./gc.sh                      # keep last 10 generations, then update
```

Don't run this casually if you might want to roll back to the previous
generation (e.g. testing an EDID override that might brick boot).

## Dotfile deploy details

`system/lib/dotfiles.nix` uses `system.activationScripts`:

- **Fish, tmux**: file-level symlinks (these write runtime state to
  their config dirs)
- **Everything else** (nvim, kitty, hypr, etc.): directory symlinks

Per-user overrides from `dotfiles/users/$USER/` shadow `dotfiles/default/`
on a per-file basis (the activation script computes the union).
