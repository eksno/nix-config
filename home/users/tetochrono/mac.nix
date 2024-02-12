{ config, lib, pkgs, ... }:

{
  imports = [
    ../../shared/headless
  ];

  home.username = "tetochrono";
  home.homeDirectory = "/home/tetochrono";

  programs.git.userName = "Daniel Aanensen";
  programs.git.userEmail = "calibor@protonmail.com";
  programs.git.extraConfig.github.user = "calibor";

  home.packages = with pkgs; [
 ];
}
