{ config, lib, pkgs, ... }:

{
  imports = [
    ../../shared
  ];

  home.username = "jorge";
  home.homeDirectory = "/home/jorge";

  programs.git.userName = "antopiahk";
  programs.git.userEmail = "antopiahk@gmail.com";
  programs.git.extraConfig.github.user = "antopiahk";

  home.packages = with pkgs; [
    spotify
    pcmanfm
  ];
}
