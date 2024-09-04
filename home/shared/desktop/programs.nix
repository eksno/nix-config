{ config, lib, pkgs, ... }:

{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-wayland;
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # programs
    speechd
    eww
    waybar
    libreoffice
    helvum
    dbeaver-bin
    obsidian # Update nevermind is was flake.nix shit <-- Update R.I.P <-- Update WE'RE SO BACK <-- I'm sorry little one, you were too trash for me to try to figure out. https://github.com/NixOS/nixpkgs/issues/302457
    bitwarden  # Update WE'RE SO BACK <-- I believed in you, but you had to be a pain.
        # vscode
    obs-studio
    brave # browser 
    chromium # backup browser 2
    easyeffects
  ];
}
