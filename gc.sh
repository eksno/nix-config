df -h /boot
sudo nix-env --delete-generations 7d
sudo nix-env --delete-generations old
sudo nix-store --gc
sudo nix-channel --update
sudo nix-env -u --always
for link in /nix/var/nix/gcroots/auto/*; do
    sudo rm "$(readlink "$link")"
done
sudo nix-collect-garbage -d
sudo nix-store --gc
sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +2
df -h /boot
./update.sh
