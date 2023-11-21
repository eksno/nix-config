#!/usr/bin/env bash

remove() {
	rm -rf ~/.config/hypr
	rm -rf ~/.config/nvim
	rm -rf ~/.config/eww
	rm -rf ~/.config/wayvnc
}

symlink() {
	mkdir ~/.config/
	ln -s ~/nix-config/home/users/calibor/hypr/hypr/ ~/.config/hypr
	ln -s ~/nix-config/home/users/calibor/hypr/nvim/ ~/.config/nvim
	ln -s ~/nix-config/home/users/calibor/hypr/eww ~/.config/eww
	ln -s ~/nix-config/home/users/calibor/hypr/wayvnc ~/.config/wayvnc
}

remove
if ! [[ $1 == 'remove' ]]; then
	symlink
fi
