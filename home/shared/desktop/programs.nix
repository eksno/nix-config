
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
    wl-clipboard
    eww-wayland
    libreoffice
    helvum
    librewolf
    bitwarden
    dbeaver
    nextcloud-client
    obsidian
    gimp
    code
    obs-studio
    playerctl # managing eww music
    brave # browser 
  ];
}
