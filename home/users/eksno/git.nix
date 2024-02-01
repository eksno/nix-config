{ config, lib, pkgs, ... }:

{
  programs.git.userName = "Jonas Lindberg";
  programs.git.userEmail = "eksno@protonmail.com";
  programs.git.extraConfig.github.user = "eksno";
}
