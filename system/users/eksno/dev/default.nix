{ ... }:

{
  imports = [
    ./nixpacks.nix
    ./python.nix
    ../../../lib/xr/driver
    ../../../lib/xr/breezy-gnome
    ../../../lib/xr/breezy-session
    ../../../lib/xr/monado-rayneo
    ../../../lib/xr/breezy-hyprland
  ];
}
