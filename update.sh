#!/usr/bin/env bash

# Verify not sudo
[[ -z $SUDO_USER ]] && echo "Running" || exit

# Get Configuration
if [[ "$HOSTNAME" = "nixos" ]] || [[ $1 == 'rename' ]]; then
	echo -n "Enter Configuration: "
	read configuration
else
	configuration=$HOSTNAME
fi

# It won't find paths not staged, we git add .
git add .

# Set Symlinks
# echo -n "n for chrono hyprland configs: "
# read hConf
if [[ "$HOSTNAME" == "chrono" ]]; then
	./home/users/lucy/hypr/symlink.sh
	echo "running chrono conf"

elif [[ "$HOSTNAME" == "lappy" ]]; then
	./home/users/lucy/dotfiles/symlink.sh
	echo "running lappy conf"
else
	./symlink.sh
	echo "running shared conf"
fi

# Update flake.lock (make sure it's synced up, can fail but should be fine)
sudo nix flake update

# It won't find paths not staged, we git add .
git add .

# Apply the updates
sudo nixos-rebuild switch --flake .#$configuration

# It won't find paths not staged, we git add .
git add .

# Update flake.lock (required again to update after package install)
nix flake update
