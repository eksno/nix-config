{ config, lib, pkgs, ... }:

{
  imports = [
    ../../shared/desktop
    ../eksno/dev
  ];

  home.username = "jorge";
  home.homeDirectory = "/home/jorge";

  programs.git.userName = "antopiahk";
  programs.git.userEmail = "antopiahk@gmail.com";
  programs.git.extraConfig.github.user = "antopiahk";

  home.packages = with pkgs; [
    spotify
    pcmanfm
    feh
    bitwarden-cli
    obs-studio
    gource
    discord
    google-chrome
    openvpn
    code-cursor
    protonvpn-gui
    supabase-cli
    github-desktop
    logiops
    imagemagick
  ];
}
