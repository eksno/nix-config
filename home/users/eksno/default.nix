{ config, lib, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./terminalprograms.nix
    ../../shared/desktop
    ../../shared/dotnet.nix
  ];

  home.username = "eksno";
  home.homeDirectory = "/home/eksno";

  home.packages = with pkgs; [
    wayvnc
    gource
    discord
    anki
    mattermost-desktop
    immersed-vr
    linuxKernel.packages.linux_zen.v4l2loopback
  ];
}
