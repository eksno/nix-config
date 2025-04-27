
{ system, inputs, config, pkgs, ... }:
{

    imports = [
        ../../shared/desktop/wayland/hyprland
        ./dev
        ./locale.nix
        ./programs.nix
    ];

    users.users.eksno = {
        isNormalUser = true;
        description = "Jonas Lindberg";
        extraGroups = [ "networkmanager" "wheel" "docker" ];
    };

    services.displayManager.sddm.settings.Autologin.User = "eksno";
    services.openssh.enable = true;
    services.xserver.xkb.layout = "us";
    console.useXkbConfig = true;
    virtualisation.docker.enable = true;
    security.polkit.enable = true;
}
