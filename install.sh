#!/usr/bin/env bash

# Verify not sudo
[[ -z $SUDO_USER ]] && echo "Running" || exit

sudo mv /etc/nixos /etc/nixos.bak  # Backup the original configuration
sudo ln -s ~/nix-config/ /etc/nixos

git -C ~/nix-config submodule update --init --recursive

echo "Done! Continue with installation by reading the README"
