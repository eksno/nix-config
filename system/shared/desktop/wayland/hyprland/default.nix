{ inputs, config, pkgs, ... }:
{
    imports = [
        ./..
    ];

    programs.hyprland = {
        enable = true;
        # set the flake package
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        # make sure to also set the portal package, so that they are in sync
        portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    };

    services.xserver.enable = true;

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
