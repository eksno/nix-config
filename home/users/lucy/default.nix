{ config, lib, pkgs, ... }:

{
  imports = [
    ../../shared
  ];

  home.username = "lucy";
  home.homeDirectory = "/home/lucy";

  programs.git.userName = "Daniel Aanensen";
  programs.git.userEmail = "calibor@protonmail.com";
  programs.git.extraConfig.github.user = "calibor";


  home.packages = with pkgs; [
 
 ];
}
