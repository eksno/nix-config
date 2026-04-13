#!/usr/bin/env bash

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

remove() {
    # User Configs
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

    # Locals
    rm -rf ~/.local/share/icons

    # Fonts
    rm -rf ~/.local/share/fonts

    # Root Configs
    sudo rm -rf /root/.config
}

create() {
    # User Configs
    mkdir -p ~/.config/

    # Hypr - composed at runtime from hosts/users/shared sub-dirs by hypr.sh
    ln -sf "$DEFAULT/hypr/hosts" ~/.config/hypr/hosts
    ln -sf "$DEFAULT/hypr/users" ~/.config/hypr/users
    ln -sf "$DEFAULT/hypr/shared" ~/.config/hypr/shared
    ./hypr.sh # source correct hypr files

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

    # Locals
    mkdir -p ~/.local/share

    link_config icons ~/.local/share/icons
    # Fonts
    ln -s /run/current-system/sw/share/X11/fonts ~/.local/share/fonts

    # Root Configs
    sudo mkdir -p /root/.config/

    sudo ln -s ~/.config /root/.config
}

remove
if ! [[ $1 == 'remove' ]]; then
    create
fi
