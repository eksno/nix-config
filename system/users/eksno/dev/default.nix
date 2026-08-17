{ ... }:

{
  imports = [
    ./nixpacks.nix
    ./python.nix

    # XR / AR-glasses stack (breezy-desktop + Monado + WayVR) is not in use on
    # verse yet, and wayvr-anv's curved-arc patch stopped applying when nixpkgs
    # moved wayvr 26.2.1 -> 26.7.1, which broke the whole system build. Re-enable
    # these once the patch is re-rolled against the current wayvr. See FIXES.md.
    # Unrelated to the BreezeX-Dark *cursor* theme, which lives in dotfiles/.
    # ../../../lib/xr/driver
    # ../../../lib/xr/breezy-gnome
    # ../../../lib/xr/breezy-session
    # ../../../lib/xr/monado-rayneo
    # ../../../lib/xr/breezy-hyprland
  ];
}
