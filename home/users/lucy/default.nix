{ config, lib, pkgs, ... }:

{
  imports = [
    ../../shared/desktop
  ];

  home.username = "lucy";
  home.homeDirectory = "/home/lucy";

  programs.git.userName = "Daniel Aanensen";
  programs.git.userEmail = "tetochrono@protonmail.com";
  programs.git.extraConfig.github.user = "LVGrinder";

  home.packages = with pkgs; [
    caprine-bin # facebook messenger
    spotify
    spotify-cli-linux
    whatsapp-for-linux
    zsa-udev-rules
    wayvnc
    webcord
    immersed-vr
    parsec-bin
    v4l-utils
    libdrm
    easyeffects
 ];
}
