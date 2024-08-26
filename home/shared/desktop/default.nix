{ config, lib, pkgs, ... }:

{
  imports = [
    ./alacritty.nix
    ./hyprland.nix
    ./kitty.nix

    ../headless

    ./programs.nix
  ];
}
