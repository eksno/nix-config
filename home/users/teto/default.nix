{ config, lib, pkgs, ... }:

{
  imports = [
    ./git.nix
    ../../shared/headless
  ];

  home.username = "teto";
  home.homeDirectory = "/home/teto";
}
