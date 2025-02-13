{ config, pkgs, ... }:
{
    imports = [
        ./..
    ];

    programs.hyprland.enable = true;

    services.xserver.enable = true;

    services.displayManager.sddm = {
        enable = true;
        package = pkgs.kdePackages.sddm;
        
        settings = {
            Autologin = {
                Session = "hyprland";
            };
        };

        enableHidpi = true;

        wayland = {
            enable = true;
        };
    };
}
