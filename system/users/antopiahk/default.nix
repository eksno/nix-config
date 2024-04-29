
{ config, pkgs, ... }:
{
    imports = [
        ../../shared/desktop/x11/gnome
        ./locale.nix
    ];

    users.users.antopiahk = {
        isNormalUser = true;
        description = "Jorge Lewis";
        extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
    };

    services.xserver.xkb.layout = "us";
    console.useXkbConfig = true;
    
    services.displayManager.sddm.settings.Autologin.User = "antopiahk";

    services.openssh.enable = true;

    virtualisation.docker.enable = true;

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [

    ];

    environment.systemPackages = with pkgs; [
        docker-compose
        gnome3.gnome-tweaks
    ];
}
