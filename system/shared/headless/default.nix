{ config, pkgs, ... }:
{
    imports = [
        ../fish.nix
        ../bluetooth.nix
        ../fish.nix
        ../fonts.nix
        ../networking.nix
        ../system.nix
    ];
    # Enable Flakes and the new command-line tool
    
    environment.systemPackages = with pkgs; [
        git # Flakes use Git to pull dependencies from data sources, so Git must be installed first
        gccgo
        libgcc
        neovim
        wget
        curl
        libsecret
    ];

    programs.tmux.enable = true;

    # Support ntfs
    boot.supportedFilesystems = [ "ntfs" ];
    
    # keyring
    services.gnome.gnome-keyring.enable = true;
}
