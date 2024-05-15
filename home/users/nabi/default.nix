{ config, lib, pkgs, ... }:

{
  imports = [
    ./git.nix
    ../../shared/desktop
  ];

  home.username = "nabi";
  home.homeDirectory = "/home/nabi";
  
  
  home.packages = with pkgs; [
    webcord
    parsec-bin
    easyeffects
    openvpn
    p7zip
    legendary-gl
    prismlauncher
    desmume
#    rustdesk
#    teamviewer
 ];
}
