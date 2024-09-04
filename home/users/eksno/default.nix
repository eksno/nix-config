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
