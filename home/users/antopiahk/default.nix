{ config, lib, pkgs, ... }:

{
  imports = [
    ../../shared/desktop
  ];

  home.username = "antopiahk";
  home.homeDirectory = "/home/antopiahk";

  programs.git.userName = "antopiahk";
  programs.git.userEmail = "antopiahk@gmail.com";
  programs.git.extraConfig.github.user = "antopiahk";

  home.packages = with pkgs; [
    spotify
    pcmanfm
    feh
    discord
    bitwarden-cli
    obs-studio
    gource
    discord
    google-chrome
    openvpn
  ];
}
