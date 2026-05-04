{ pkgs, ... }:

let
  breezyGnome = pkgs.callPackage ./package.nix { };
in
{
  # Install the extension into the system closure so XDG_DATA_DIRS picks it
  # up. NB: this does NOT enable the extension globally — gnome-shell only
  # activates extensions listed in `org.gnome.shell enabled-extensions`, and
  # the breezy-sideview wrapper sets that key on its own runtime dir.
  environment.systemPackages = [ breezyGnome ];
}
