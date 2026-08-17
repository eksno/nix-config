{ pkgs, ... }:

let
  breezyRecenter = pkgs.callPackage ./package.nix { };
in
{
  environment.systemPackages = [ breezyRecenter ];
}
