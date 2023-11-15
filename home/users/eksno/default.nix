{ config, lib, pkgs, ... }:

{
  imports = [
    ../../shared
  ];

  home.username = "eksno";
  home.homeDirectory = "/home/eksno";

  programs.git.userName = "Jonas Lindberg";
  programs.git.userEmail = "eksno@protonmail.com";
  programs.git.extraConfig.github.user = "eksno";


  home.packages = with pkgs; [
    sqlcmd
  ];
}
