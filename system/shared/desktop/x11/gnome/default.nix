{ config, pkgs, ... }:
{
    imports = [
        ./..
    ];

    services.xserver = {
        enable = true;
        displayManager.gdm.enable = true;
        desktopManager.gnome.enable = true;
    };

    environment.systemPackages = with pkgs; [
        gnome-tweaks
    ];
}
