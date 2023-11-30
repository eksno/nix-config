#!/usr/bin/env bash

remove() {
	rm -rf ~/.config/hypr/hyprland.conf
}

create() {
	echo "source = ~/.config/hypr/users/$USER/default.conf" | tee ~/.config/hypr/hyprland.conf
}

remove
if ! [[ $1 == 'remove' ]]; then
	create
fi
