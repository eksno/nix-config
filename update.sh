#!/usr/bin/env bash

# Verify not sudo
[[ -z $SUDO_USER ]] && echo "Running" || exit

# ---- Parse args ----
do_nix=false
do_symlink=false
reconfigure=false
for arg in "$@"; do
    case "$arg" in
        nix) do_nix=true ;;
        symlink) do_symlink=true ;;
        reconfigure) reconfigure=true ;;
        *) echo "Unknown arg: $arg" >&2; echo "Usage: $0 [nix] [symlink] [reconfigure]" >&2; exit 1 ;;
    esac
done

# `reconfigure` alone preserves old behavior: prompt for host + both steps
if $reconfigure && ! $do_nix && ! $do_symlink; then
    do_nix=true
    do_symlink=true
fi

# Bare invocation: nix only (matches old `./update.sh`)
if ! $do_nix && ! $do_symlink; then
    do_nix=true
fi

# Use `sudo -A` when SUDO_ASKPASS is set (lets non-TTY callers like Claude Code
# authenticate via secure-askpass); fall back to plain `sudo` otherwise.
SUDO=("sudo")
[[ -n "$SUDO_ASKPASS" ]] && SUDO=("sudo" "-A")

"${SUDO[@]}" echo "Authenticated." || exit

# It won't find paths not staged, we git add .
git add .

# ---- Host selection (only needed for nix rebuild) ----
if $do_nix; then
    if [[ "$HOSTNAME" = "nixos" ]] || $reconfigure; then
        echo -n "Enter Host: "
        read -r host
    else
        host=$HOSTNAME
    fi
fi

# ---- Symlinks (was symlink.sh + hypr.sh) ----
if $do_symlink; then
    DOTFILES="$HOME/nix-config/dotfiles"
    DEFAULT="$DOTFILES/default"
    OVERRIDE="$DOTFILES/users/$USER"

    # Link $DEFAULT/<name> (or $OVERRIDE/<name> if present) into $target.
    link_config() {
        local name="$1"
        local target="$2"
        if [[ -e "$OVERRIDE/$name" ]]; then
            ln -s "$OVERRIDE/$name" "$target"
        else
            ln -s "$DEFAULT/$name" "$target"
        fi
    }

    # Remove existing
    rm -rf ~/.config/hypr/*
    rm -rf ~/.config/fish
    rm -rf ~/.config/eww
    rm -rf ~/.config/tmux
    rm -rf ~/.config/kitty
    rm -rf ~/.config/mako
    rm -rf ~/.config/nvim
    rm -rf ~/.config/btop
    rm -rf ~/.config/tofi
    rm -rf ~/.config/waybar
    rm -rf ~/.config/xdg-desktop-portal
    rm -rf ~/.local/share/icons
    rm -rf ~/.local/share/fonts
    "${SUDO[@]}" rm -rf /root/.config

    # Create
    mkdir -p ~/.config/

    # Hypr - composed at runtime from hosts/users/shared sub-dirs
    ln -sf "$DEFAULT/hypr/hosts" ~/.config/hypr/hosts
    ln -sf "$DEFAULT/hypr/users" ~/.config/hypr/users
    ln -sf "$DEFAULT/hypr/shared" ~/.config/hypr/shared
    rm -rf ~/.config/hypr/hyprland.conf
    echo "source = ~/.config/hypr/users/$USER/default.conf" | tee -a ~/.config/hypr/hyprland.conf
    echo "source = ~/.config/hypr/hosts/$HOSTNAME/default.conf" | tee -a ~/.config/hypr/hyprland.conf
    hyprctl reload

    link_config fish ~/.config/fish
    link_config tmux ~/.config/tmux
    link_config eww ~/.config/eww
    link_config kitty ~/.config/kitty
    link_config mako ~/.config/mako
    link_config nvim ~/.config/nvim
    link_config btop ~/.config/btop
    link_config tofi ~/.config/tofi
    link_config waybar ~/.config/waybar
    link_config xdg-desktop-portal ~/.config/xdg-desktop-portal

    mkdir -p ~/.local/share
    link_config icons ~/.local/share/icons
    ln -s /run/current-system/sw/share/X11/fonts ~/.local/share/fonts

    "${SUDO[@]}" mkdir -p /root/.config/
    "${SUDO[@]}" ln -s ~/.config /root/.config
fi

# ---- Nix rebuild ----
if $do_nix; then
    # Update flake.lock (make sure it's synced up, can fail but should be fine)
    "${SUDO[@]}" nix flake update

    # It won't find paths not staged, we git add .
    git add .

    # Apply the updates
    "${SUDO[@]}" nixos-rebuild switch --flake "./#$host" --impure

    # It won't find paths not staged, we git add .
    git add .

    # Update flake.lock (required again to update after package install)
    nix flake update

    df -h /boot
fi

# ---- Proactively configure secure-askpass if missing ----
# Lets `sudo -A` work in non-TTY shells (Claude Code's `!`, scripts, etc.)
# without weakening sudoers. Prompts only when no encrypted password file exists.
askpass_manager="$HOME/.local/share/secure-askpass/askpass-manager"
if [[ -x "$askpass_manager" ]] \
   && [[ ! -e "$HOME/.sudo_askpass.age" ]] \
   && [[ ! -e "$HOME/.sudo_askpass.ssh" ]]; then
    echo
    echo "secure-askpass isn't configured yet — setting it up now so \`sudo -A\` works."
    "$askpass_manager" set
fi
