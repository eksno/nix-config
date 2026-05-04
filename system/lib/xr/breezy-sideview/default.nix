{ pkgs, ... }:

let
  breezyGnome = pkgs.callPackage ../breezy-gnome/package.nix { };
  breezySideview = pkgs.callPackage ./package.nix { inherit breezyGnome; };
in
{
  environment.systemPackages = [ breezySideview ];

  # Closing the lid while docked + glasses active should not suspend the
  # session — sideview is the whole point of running headless on the
  # external display path.
  services.logind.lidSwitchExternalPower = "ignore";
}
