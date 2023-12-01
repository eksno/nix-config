#!/usr/bin/env bash

# Verify not sudo
[[ -z $SUDO_USER ]] && echo "Running" || exit

# Get Host
if [[ "$HOSTNAME" = "nixos" ]] || [[ $1 == 'reconfigure' ]]; then
	echo -n "Enter Host: "
	read host
else
	host=$HOSTNAME
fi

# It won't find paths not staged, we git add .
git add .

# Set Symlinks
# echo -n "n for chrono hyprland configs: "
# read hConf
./symlink.sh
echo "running shared conf"

# Update flake.lock (make sure it's synced up, can fail but should be fine)
sudo nix flake update

# It won't find paths not staged, we git add .
git add .

# Apply the updates
sudo nixos-rebuild switch --flake .#$configuration

# It won't find paths not staged, we git add .
git add .

# Source correct hyprland stuff
./hypr.sh

# Update flake.lock (required again to update after package install)
nix flake update
