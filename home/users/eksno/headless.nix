{ config, lib, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./terminalprograms.nix
    ../../shared/headless
    ../../shared/dotnet.nix
  ];

  home.username = "nixos";
  home.homeDirectory = "/home/nixos";
}
