{ config, lib, pkgs, ... }:

{
  imports = [
    ../../shared
  ];

  programs.git.userName = "Daniel Aanensen";
  programs.git.userEmail = "calibor@protonmail.com";
}