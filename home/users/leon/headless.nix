{ config, lib, pkgs, ... }:

{
  imports = [
    ./git.nix
    ../../shared/headless
  ];

  home.username = "nixos";
  home.homeDirectory = "/home/nixos";
}
