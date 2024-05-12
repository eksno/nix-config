{ config, lib, pkgs, ... }:

{
  imports = [
    ./git.nix
    ../../shared/desktop
  ];

  home.username = "teto";
  home.homeDirectory = "/home/teto";
  
  
  home.packages = with pkgs; [
    caprine-bin # facebook messenger
    spotify
    spotify-cli-linux
    whatsapp-for-linux
    zsa-udev-rules
    wayvnc
    webcord
    parsec-bin
    v4l-utils
    libdrm
    easyeffects
    openvpn
    p7zip
    wineWowPackages.waylandFull
    legendary-gl
    signal-desktop
    prismlauncher
#    rustdesk
#    teamviewer
 ];
}
