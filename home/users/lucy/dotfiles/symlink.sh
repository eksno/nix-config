#!/usr/bin/env bash

remove() {
	# Configs
	rm -rf ~/.config/hypr
	rm -rf ~/.config/nvim
	rm -rf ~/.config/eww
	rm -rf ~/.config/uwu-pics/
	rm -rf ~/.config/tofi

	# Fonts
	rm -rf ~/.local/share/fonts
}

symlink() {
	mkdir -p ~/.config/

	# Configs
	ln -s ~/nix-config/home/users/lucy/dotfiles/hypr/ ~/.config/hypr
	ln -s ~/nix-config/home/users/lucy/dotfiles/nvim/ ~/.config/nvim
	ln -s ~/nix-config/home/users/lucy/dotfiles/eww ~/.config/eww
	ln -s ~/uwu-pics/ ~/.config/uwu-pics
	ln -s ~/nix-config/dotfiles/tofi ~/.config/tofi

	# Fonts
	ln -s /run/current-system/sw/share/X11/fonts ~/.local/share/fonts
}

remove
if ! [[ $1 == 'remove' ]]; then
	symlink
fi
