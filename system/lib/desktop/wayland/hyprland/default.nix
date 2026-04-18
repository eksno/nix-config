{ config, pkgs, ... }:
{
  imports = [
    ./..
  ];

  programs.hyprland.enable = true;
  programs.uwsm.enable = true;

  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;

    settings = {
      Autologin = {
        Session = "hyprland-uwsm.desktop";
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
