{ pkgs, inputs, ... }:

let
  # Pull `gnome-shell` from a pinned nixos-25.05 nixpkgs (GNOME 48). v49
  # removed `--nested` from gnome-shell, which is the only way to run it
  # on a non-GNOME wayland host like Hyprland. Mixing pkg sets is fine —
  # gnome-shell's runtime closure (mutter, gjs, glib) is self-contained.
  pkgsGnome48 = inputs.nixpkgs-gnome48.legacyPackages.${pkgs.system};
  breezyGnome = pkgs.callPackage ../breezy-gnome/package.nix { };
  breezySideview = pkgs.callPackage ./package.nix {
    inherit breezyGnome;
    inherit (pkgsGnome48) gnome-shell;
  };
in
{
  environment.systemPackages = [ breezySideview ];

  # Closing the lid while docked + glasses active should not suspend the
  # session — sideview is the whole point of running headless on the
  # external display path. The legacy `services.logind.lidSwitchExternalPower`
  # option was renamed to settings.Login.HandleLidSwitchExternalPower in
  # nixpkgs unstable.
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
}
