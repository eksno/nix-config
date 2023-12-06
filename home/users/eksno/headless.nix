{ config, lib, pkgs, ... }:

{
  imports = [
    ../../shared/headless
    ../../shared/dotnet.nix
  ];

  home.username = "nixos";
  home.homeDirectory = "/home/nixos";

  programs.git.userName = "Jonas Lindberg";
  programs.git.userEmail = "eksno@protonmail.com";
  programs.git.extraConfig.github.user = "eksno";

  home.packages = with pkgs; [
    sqlcmd
  ];
}
