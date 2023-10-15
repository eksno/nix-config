#!/usr/bin/env bash

remove() {
	rm -rf ~/.config/hypr
	rm -rf ~/.config/nvim
	rm -rf ~/.config/eww
}

symlink() {
	ln -s ~/nix-config/dotfiles/hypr ~/.config/hypr
	ln -s ~/nix-config/dotfiles/nvim ~/.config/nvim
	ln -s ~/nix-config/dotfiles/eww ~/.config/eww
}

remove
if ! [[ $1 == 'remove' ]]; then
	symlink
fi
