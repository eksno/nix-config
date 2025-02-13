#!/usr/bin/env bash

# Verify not sudo
[[ -z $SUDO_USER ]] && echo "Running" || exit

sudo echo "Authenticated." || exit

# It won't find paths not staged, we git add .
git add .

# Get Host and Symlink
if [[ "$HOSTNAME" = "nixos" ]] || [[ $1 == 'reconfigure' ]] || [[ $2 == 'reconfigure' ]]; then
    echo -n "Enter Host: "
    read -r host
    ./symlink.sh
else
    host=$HOSTNAME

    if [[ $1 == 'symlink' ]] || [[ $2 == 'symlink' ]]; then
        # Set Symlinks
        ./symlink.sh
    fi
fi

# Update flake.lock (make sure it's synced up, can fail but should be fine)
sudo nix flake update

# It won't find paths not staged, we git add .
git add .

# Apply the updates
sudo nixos-rebuild switch --flake "./#$host" --impure

# It won't find paths not staged, we git add .
git add .

# Update flake.lock (required again to update after package install)
nix flake update

df -h /boot
