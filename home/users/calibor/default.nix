{ config, lib, pkgs, ... }:

{
  imports = [
    ../../shared
  ];

  home.username = "calibor";
  home.homeDirectory = "/home/calibor";

  programs.git.userName = "Daniel Aanensen";
  programs.git.userEmail = "calibor@protonmail.com";
  programs.git.extraConfig.github.user = "calibor";
}