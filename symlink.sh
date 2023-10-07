#!/usr/bin/env bash

remove() {
	rm -rf ~/.config/hypr
	rm -rf ~/.config/nvim
}

symlink() {
	ln -s ~/nix-config/dotfiles/hypr ~/.config/hypr
	ln -s ~/nix-config/dotfiles/nvim ~/.config/nvim
}

remove
if ! [[ $1 == 'remove' ]]; then
	symlink
fi
