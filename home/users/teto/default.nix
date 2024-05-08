{ config, lib, pkgs, ... }:

{
  imports = [
    ./git.nix
    ../../shared/desktop
  ];

  home.username = "teto";
  home.homeDirectory = "/home/teto";

  home.packages = with pkgs; [
  ];
}
