#!/usr/bin/env bash

# Verify not sudo
[[ -z $SUDO_USER ]] && echo "Running" || exit

sudo mv /etc/nixos /etc/nixos.bak  # Backup the original configuration
sudo ln -s ~/nix-config/ /etc/nixos

echo "Done! Continue with installation by reading the README"
