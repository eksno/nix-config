#!/usr/bin/env bash

# Verify not sudo
[[ -z $SUDO_USER ]] && echo "Running" || exit

# Get configuration
echo -n "Enter Configuration: "
read configuration

# It won't find paths not staged, we git add .
git add .

# Set Symlinks
./symlink.sh

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
