{ pkgs, ... }:

{
    imports = [
        ./git.nix
        ../../shared/desktop
        ./autojump.nix
    ];

    home.username = "eksno";
    home.homeDirectory = "/home/eksno";


    home.packages = with pkgs; [
        brightnessctl
        axel
        glib
        btop
        kanata-with-cmd

        qbittorrent
        hoppscotch
        beeper
        bitwarden-cli
        obs-studio
        gource
        anki
        easyeffects
        webcord
    ];

    programs.nixcord = {
        enable = true;
        quickCss = "
        /**
        * @name Dark Matter
        * @author Tropical#8908, Hammock#3110
        * @version 3.0.0
        * @description A cold, dark & frosty theme.
        * @source https://github.com/DiscordStyles/DarkMatter/
        */

        @import url('https://DiscordStyles.github.io/DarkMatter/src/base.css');

        /* Variables */
        :root {
            --avatar-size: 32px;
            --background-image: url('https://i.imgur.com/7SbtKvw.png');
            --home-image: url('https://i.imgur.com/233d55Y.gif');
            --background-solid: #161921;
            --background-solid-dark: #101218;
            --background-solid-darker: #0c0e12;
            --accent: 37, 172, 232;
            --accent-alt: 29, 101, 134;
        }";
        config = {
            useQuickCss = true;
        };
    };
}
