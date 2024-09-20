{ config, lib, pkgs, ... }:

{
    imports = [
        ./git.nix
        ../../shared/desktop
        ./autojump.nix
    ];

    home.username = "eksno";
    home.homeDirectory = "/home/eksno";


    home.packages = with pkgs; [
        hoppscotch
        brightnessctl
        glib
        beeper
        bitwarden-cli
        obs-studio
        gource
        anki
        easyeffects
        webcord
    ];
}
