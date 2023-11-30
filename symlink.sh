#!/usr/bin/env bash

remove() {
	# Configs
	rm -rf ~/.config/hypr
	rm -rf ~/.config/nvim
	rm -rf ~/.config/eww
	rm -rf ~/.config/tofi

	# Fonts
	rm -rf ~/.local/share/fonts
}

create() {
	mkdir -p ~/.config/
	mkdir -p ~/.config/hypr

	# Configs
	ln -s ~/nix-config/dotfiles/hypr/users ~/.config/hypr/users
	ln -s ~/nix-config/dotfiles/hypr/hosts ~/.config/hypr/hosts
	ln -s ~/nix-config/dotfiles/hypr/shared ~/.config/hypr/shared
	ln -s ~/nix-config/dotfiles/nvim ~/.config/nvim
	ln -s ~/nix-config/dotfiles/eww ~/.config/eww
	ln -s ~/nix-config/dotfiles/tofi ~/.config/tofi

	# Fonts
	ln -s /run/current-system/sw/share/X11/fonts ~/.local/share/fonts
}

remove
if ! [[ $1 == 'remove' ]]; then
	create
fi
