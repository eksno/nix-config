{ pkgs, ... }:

let
  monadoRayneo = pkgs.callPackage ./package.nix { };
in
{
  # Just the binary on PATH for now — runtime/service wiring lands in
  # Phase 2 (breezy-hyprland) once the MR is confirmed to enumerate the
  # glasses. Until then `monado-cli probe` is the only thing we run.
  environment.systemPackages = [ monadoRayneo ];
}
