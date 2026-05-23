{ ... }:

{
  imports = [
    ./nixpacks.nix
    ./python.nix
    ../../../lib/xr/driver
    ../../../lib/xr/breezy-recenter
    ../../../lib/xr/monado-rayneo
    ../../../lib/xr/breezy-hyprland
  ];
}
