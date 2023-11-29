#!/usr/bin/env bash

remove() {
	# Configs
	rm -rf ~/.config/hypr/modules
	rm -rf ~/.config/hypr/profiles
	rm -rf ~/.config/nvim
	rm -rf ~/.config/eww
	rm -rf ~/.config/tofi

	# Fonts
	rm -rf ~/.local/share/fonts
}

symlink() {
	mkdir -p ~/.config/

	# Configs
	ln -s ~/nix-config/dotfiles/hypr/modules ~/.config/hypr
	ln -s ~/nix-config/dotfiles/hypr/profiles ~/.config/hypr
	ln -s ~/nix-config/dotfiles/nvim ~/.config/nvim
	ln -s ~/nix-config/dotfiles/eww ~/.config/eww
	ln -s ~/nix-config/dotfiles/tofi ~/.config/tofi

	# Fonts
	ln -s /run/current-system/sw/share/X11/fonts ~/.local/share/fonts
}

remove
if ! [[ $1 == 'remove' ]]; then
	symlink
fi
