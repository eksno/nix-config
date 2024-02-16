{ config, lib, pkgs, ... }:

{
  programs.git.userName = "Daniel Aanensen";
  programs.git.userEmail = "tetochrono@protonmail.com";
  programs.git.extraConfig.github.user = "calibor";
}
