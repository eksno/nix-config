
{ config, pkgs, ... }:
{
    imports = [
        ../../shared/desktop/x11/gnome
        ./locale.nix
        ./steamcontroller.nix
    ];

    users.users.biwas = {
        isNormalUser = true;
        description = "Biwas Bhandari";
        extraGroups = [ "networkmanager" "wheel" "video" "docker" "input" ];
    };

    services.xserver.xkb.layout = "us";
    console.useXkbConfig = true;
    
    services.displayManager.sddm.settings.Autologin.User = "biwas";

    services.openssh.enable = true;

    virtualisation.docker.enable = true;

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [

    ];

    environment.systemPackages = with pkgs; [
        docker-compose
        xboxdrv
        steam
    ];

    boot.initrd.kernelModules = [ "usbhid" "joydev" "xpad" ];
    boot.extraModprobeConfig = '' options bluetooth disable_ertm=1 '';

    programs.steam = {
        enable = true;
        remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
        dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
        localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };

    hardware.pulseaudio.support32Bit = true;
    hardware.graphics.enable32Bit = true;
    hardware.steam-hardware.enable = true;
}
