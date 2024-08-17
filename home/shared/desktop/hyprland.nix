
{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    # hyprland
    dunst # notifications
    libnotify # Required by dunst
    tofi # minimalist app launcher
    grim # screenshot utility
    slurp # region selection
    swww # wallpaper engine
    mpvpaper # wallpaper video engine / possibly can remove this
    lz4 # helps swww
    waypaper # gui wallpaper setter / possibly can remove this
    xdg-utils # commands for xdg, setting default apps and such
    ipcalc  # it is a calculator for the IPv4/v6 addresses
  ];
}
