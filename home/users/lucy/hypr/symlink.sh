#!/usr/bin/env bash

remove() {
	rm -rf ~/.config/hypr
	rm -rf ~/.config/nvim
	rm -rf ~/.config/eww
}
symlink() {
	mkdir ~/.config/
	ln -s ~/nix-config/home/users/lucy/dotfiles/hypr/ ~/.config/hypr
	ln -s ~/nix-config/home/users/lucy/dotfiles/nvim/ ~/.config/nvim
	ln -s ~/nix-config/home/users/lucy/dotfiles/eww ~/.config/eww

}

remove
if ! [[ $1 == 'remove' ]]; then
	symlink
fi
