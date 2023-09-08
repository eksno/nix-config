# Update flake.lock
nix flake update

# Apply the updates
sudo nixos-rebuild switch --flake .#virteks
