{ config, pkgs, ... }:
{
    imports = [
        ./..
    ];

    programs = {
        hyprland = {
            enable = true;
            xwayland.enable = true;
        };
    };

    services.xserver = {
        enable = true;
    };

    services.displayManager.sddm = {
        enable = true;
        
        settings = {
            Autologin = {
                Session = "hyprland";
            };
        };

        enableHidpi = true;
        theme = "sugar-dark";

        wayland = {
            enable = true;
        };
    };
}
