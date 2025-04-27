#!/usr/bin/env bash

remove() {
    # User Configs
    rm -rf ~/.config/fish
    rm -rf ~/.config/eww
    rm -rf ~/.config/tmux
    rm -rf ~/.config/kitty
    rm -rf ~/.config/nvim
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

    ln -s ~/nix-config/dotfiles/fish ~/.config/fish
    ln -s ~/nix-config/dotfiles/tmux ~/.config/tmux
    ln -s ~/nix-config/dotfiles/eww ~/.config/eww
    ln -s ~/nix-config/dotfiles/kitty ~/.config/kitty
    ln -s ~/nix-config/dotfiles/nvim ~/.config/nvim
    ln -s ~/nix-config/dotfiles/tofi ~/.config/tofi
    ln -s ~/nix-config/dotfiles/waybar ~/.config/waybar
    ln -s ~/nix-config/dotfiles/xdg-desktop-portal ~/.config/xdg-desktop-portal

    # Locals
    mkdir -p ~/.local/share

    ln -s ~/nix-config/dotfiles/icons ~/.local/share/icons
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
