
{ config, pkgs, ... }:
{
    imports = [
        ../../shared/desktop/x11/gnome
        ./locale.nix
    ];

    users.users.jorge = {
        isNormalUser = true;
        description = "Jorge Lewis";
        extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
        packages = with pkgs; [
        # ...
        (wrapOBS {
            plugins = with obs-studio-plugins; [
            droidcam-obs
            ];
        })
        # ...
        ];
    };

    # Virtual cam settings: see https://wiki.nixos.org/wiki/OBS_Studio#Using_the_Virtual_Camera
    boot.extraModulePackages = with config.boot.kernelPackages; [
        v4l2loopback
    ];
    boot.extraModprobeConfig = ''
        options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
    '';
    security.polkit.enable = true;

    services.xserver.xkb.layout = "us";
    console.useXkbConfig = true;
    
    services.displayManager.sddm.settings.Autologin.User = "jorge";

    services.openssh.enable = true;

    virtualisation.docker.enable = true;

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [

    ];

    environment.systemPackages = with pkgs; [
        docker-compose
        code-cursor
        caligula
    ];

}
