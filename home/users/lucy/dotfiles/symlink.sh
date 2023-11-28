#!/usr/bin/env bash

remove() {
	rm -rf ~/.config/hypr
	rm -rf ~/.config/nvim
	rm -rf ~/.config/eww
	rm -rf ~/.config/uwu-pics/
}

symlink() {
	mkdir ~/.config/
	ln -s ~/nix-config/home/users/lucy/dotfiles/hypr/ ~/.config/hypr
	ln -s ~/nix-config/home/users/lucy/dotfiles/nvim/ ~/.config/nvim
	ln -s ~/nix-config/home/users/lucy/dotfiles/eww ~/.config/eww
	ln -s ~/uwu-pics/ ~/.config/uwu-pics/
}

remove
if ! [[ $1 == 'remove' ]]; then
	symlink
fi
