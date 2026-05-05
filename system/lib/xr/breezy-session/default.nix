{ lib, pkgs, ... }:

let
  breezyGnome = pkgs.callPackage ../breezy-gnome/package.nix { };
in
{
  # Register a real GNOME-on-Wayland session that SDDM can list alongside
  # Hyprland. The plan is: Hyprland keeps autologging in for daily use; when
  # Jorge dons the glasses he logs out and picks "GNOME on Wayland" in the
  # SDDM greeter, where breezy-gnome auto-loads.
  #
  # See `xr/plans/02-gnome-breezy-session-2026-05-05.md` for the architecture
  # rationale (nested gnome-shell on Hyprland is dead — this is the smallest
  # path that delivers world-locked surfaces without a multi-week
  # wlroots-native rewrite).
  services.desktopManager.gnome.enable = true;

  # `desktopManager.gnome.enable` flips on `services.displayManager.gdm.enable`
  # transitively. Override back to false — SDDM is the DM for both sessions on
  # this host. mkForce because the gnome module sets gdm with non-default
  # priority via mkDefault chains.
  services.displayManager.gdm.enable = lib.mkForce false;

  # Lid-close while docked + glasses active should not suspend. Migrated from
  # the deleted breezy-sideview module — same intent.
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

  # Re-state the breezy-gnome package as a system package so this module is
  # self-contained for the eksno wiring. The breezy-gnome module also adds
  # it; nixpkgs dedupes in environment.systemPackages.
  environment.systemPackages = [ breezyGnome ];

  # Seed dconf system-wide so first GNOME login already has the breezy
  # extension enabled with the 2-screen preset. Schema keys verified against
  # com.xronlinux.BreezyDesktop in breezy-gnome v2.9.12 (display-distance,
  # display-size, curved-display, widescreen-mode all present).
  #
  # The list is wrapped in `mkArray` so toDconfINI emits `['x']` (GVariant
  # string list) rather than the bare nix list serialization. Doubles and
  # bools serialize unambiguously without wrapping.
  #
  # Leaves user-db:user first in the profile chain (NixOS's default), so
  # gnome-control-center / dconf-editor edits still override these defaults
  # for the live user.
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          enabled-extensions = lib.gvariant.mkArray [ "breezydesktop@xronlinux.com" ];
        };
        "com/xronlinux/BreezyDesktop" = {
          display-distance = 1.05;
          display-size = 1.0;
          curved-display = false;
          widescreen-mode = false;
        };
      };
    }
  ];
}
