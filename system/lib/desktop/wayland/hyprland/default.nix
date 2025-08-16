{ config, pkgs, ... }:
{
  imports = [
    ./..
  ];

  programs.hyprland.enable = true;

  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;

    settings = {
      Autologin = {
        Session = "Hyprland";
      };
    };

    enableHidpi = true;

    wayland = {
      enable = true;
    };
  };

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-gtk
    pkgs.xdg-desktop-portal-hyprland
  ];
}
