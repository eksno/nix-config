{ config, lib, pkgs, ... }:

{
  programs.git.userName = "Leon Nilsson";
  programs.git.userEmail = "leonlamnilsson@gmail.com";
  programs.git.extraConfig.github.user = "failandimprove1";
}
