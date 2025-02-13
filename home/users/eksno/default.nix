{ pkgs, ... }:

{
    imports = [
        ./git.nix
        ../../shared/desktop
        ./autojump.nix
        ./dev
    ];

    home.username = "eksno";
    home.homeDirectory = "/home/eksno";

    home.packages = with pkgs; [
        brightnessctl
        axel
        glib
        btop

        tmux
        google-chrome
        postgresql
        qbittorrent
        hoppscotch
        beeper
        obs-studio
        gource
        anki
        easyeffects
        discord
    ];
}
