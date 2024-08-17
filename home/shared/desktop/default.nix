{ config, lib, pkgs, ... }:

{
  imports = [
    ./alacritty.nix
    ./hyprland.nix
    ./kitty.nix
    ./librewolf.nix

    ../headless

    ./programs.nix
  ];
}
