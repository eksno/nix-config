{ config, pkgs, ... }:
{
    imports = [  # Do not import from ../../shared here. This is just hardware/device related.
        ./hardware-configuration.nix  # Include the results of the hardware scan.
        ./boot.nix
        ../../device/intel
    ];

    services.xserver.exportConfiguration = true;

    networking.hostName = "verse"; # Define your hostname.

    # theme
    # environment.variables.GTK_THEME = "catppuccin-mocha-standard";
    # environment.variables.XCURSOR_THEME = "Catppuccin-Mocha";
    # environment.variables.XCURSOR_SIZE = "24";
    # environment.variables.HYPRCURSOR_THEME = "Catppuccin-Mocha";
    # environment.variables.HYPRCURSOR_SIZE = "24";
    # qt.enable = true;
    # qt.platformTheme = "gtk2";
    # qt.style = "gtk2";
    #
    # environment.systemPackages = with pkgs; [
    #     numix-icon-theme-circle
    #     colloid-icon-theme
    #     catppuccin-gtk
    #     catppuccin-kvantum
    #     catppuccin-cursors
    # ];
} 
