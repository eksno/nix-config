{ config, lib, pkgs, ... }:

{
    imports = [
        ./git.nix
        ../../shared/desktop
        ./autojump.nix
    ];

    home.username = "biwas";
    home.homeDirectory = lib.mkForce "/home/biwas";

    home.packages = with pkgs; [
        glib
        beeper
        bitwarden-cli
        obs-studio
        gource
        easyeffects
        webcord
    ];
}
