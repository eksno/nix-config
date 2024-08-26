{ config, lib, pkgs, ...}:

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
    zsa-udev-rules
    webcord
    parsec-bin
    easyeffects
    p7zip
    wineWowPackages.waylandFull
    legendary-gl
    signal-desktop
    prismlauncher
    desmume
    simplex-chat-desktop
    brightnessctl
#    rustdesk
#    teamviewer
 ];

}
