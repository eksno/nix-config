{ config, lib, pkgs, ... }:

{
  imports = [
    ../../shared/desktop
  ];

  home.username = "lucy";
  home.homeDirectory = "/home/lucy";

  programs.git.userName = "Daniel Aanensen";
  programs.git.userEmail = "calibor@protonmail.com";
  programs.git.extraConfig.github.user = "calibor";

  home.packages = with pkgs; [
    caprine-bin # facebook messenger
    spotify
    spotify-cli-linux
    whatsapp-for-linux
    zsa-udev-rules
    wayvnc
    webcord
    immersed-vr
    libva 
    v4l2-relayd
    poetry
    python311Packages.youtube-transcript-api
    yt-dlp
    parsec-bin
 ];
}
