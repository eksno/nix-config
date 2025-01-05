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
        steam
        droidcam        # Add DroidCam
        android-tools    # Add ADB
        v4l2loopback    # Add v4l2loopback for virtual webcam support
    ];

    boot.initrd.kernelModules = [ "usbhid" "joydev" "xpad" "v4l2loopback" ];  # Load v4l2loopback
    boot.extraModprobeConfig = '' options bluetooth disable_ertm=1 '';

    programs.steam = {
        enable = true;
        remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
        dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
        localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };

    hardware.steam-hardware.enable = true;
}
