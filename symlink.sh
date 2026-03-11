#!/usr/bin/env bash

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

    ln -s ~/nix-config/dotfiles/hypr/hosts ~/.config/hypr/hosts
    ln -s ~/nix-config/dotfiles/hypr/users ~/.config/hypr/users
    ln -s ~/nix-config/dotfiles/hypr/shared ~/.config/hypr/shared
    ./hypr.sh # source correct hypr files

    # Fish - shared base + per-user overrides
    mkdir -p ~/.config/fish/functions
    for f in ~/nix-config/dotfiles/fish/*; do
        fname="$(basename "$f")"
        [[ "$fname" == "functions" ]] && continue
        [[ -e ~/nix-config/dotfiles/users/$USER/fish/$fname ]] && continue
        ln -s "$f" ~/.config/fish/"$fname"
    done
    for f in ~/nix-config/dotfiles/fish/functions/*; do
        fname="$(basename "$f")"
        [[ -e ~/nix-config/dotfiles/users/$USER/fish/functions/$fname ]] && continue
        ln -s "$f" ~/.config/fish/functions/"$fname"
    done
    if [[ -d ~/nix-config/dotfiles/users/$USER/fish ]]; then
        for f in ~/nix-config/dotfiles/users/$USER/fish/*; do
            [[ "$(basename "$f")" == "functions" ]] && continue
            ln -s "$f" ~/.config/fish/"$(basename "$f")"
        done
        if [[ -d ~/nix-config/dotfiles/users/$USER/fish/functions ]]; then
            for f in ~/nix-config/dotfiles/users/$USER/fish/functions/*; do
                ln -s "$f" ~/.config/fish/functions/"$(basename "$f")"
            done
        fi
    fi

    # Tmux - per-user with shared fallback
    if [[ -d ~/nix-config/dotfiles/users/$USER/tmux ]]; then
        ln -s ~/nix-config/dotfiles/users/$USER/tmux ~/.config/tmux
    else
        ln -s ~/nix-config/dotfiles/tmux ~/.config/tmux
    fi

    ln -s ~/nix-config/dotfiles/eww ~/.config/eww
    ln -s ~/nix-config/dotfiles/kitty ~/.config/kitty
    ln -s ~/nix-config/dotfiles/mako ~/.config/mako
    ln -s ~/nix-config/dotfiles/nvim ~/.config/nvim
    ln -s ~/nix-config/dotfiles/btop ~/.config/btop
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
