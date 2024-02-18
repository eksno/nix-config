{ config, lib, pkgs, ... }:

{
  imports = [
    ./git.nix
    ../../shared/desktop
  ];

  home.username = "eksno";
  home.homeDirectory = "/home/eksno";

  home.packages = with pkgs; [
    bitwarden-cli
    obs-studio
    gource
    discord
    anki
    mattermost-desktop
    immersed-vr
    linuxKernel.packages.linux_zen.v4l2loopback
  ];
}
