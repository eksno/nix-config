
{ system, inputs, config, pkgs, ... }:
{

    imports = [
        ../../shared/desktop/wayland/hyprland
        ./locale.nix
        ./steamcontroller.nix
    ];

    users.users.eksno = {
        isNormalUser = true;
        description = "Jonas Lindberg";
        extraGroups = [ "networkmanager" "wheel" "docker" "input" "uinput" "audio" "pulse" "storage" "network" "netdev" "games" ];
    };

    services.xserver.xkb.layout = "us";
    console.useXkbConfig = true;


    services.displayManager.sddm.settings.Autologin.User = "eksno";
    services.openssh.enable = true;

    virtualisation.docker.enable = true;

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [

    ];

    environment.systemPackages = with pkgs; [
        inputs.zen-browser.packages."${system}".default
        lm_sensors
        docker-compose
        steam
        v4l-utils
        beeper
        tmux
    ];

    boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    boot.kernelModules = [ "v4l2loopback" ];
    boot.initrd.kernelModules = [ "usbhid" "joydev" "xpad" ];
    boot.extraModprobeConfig = '' options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1 bluetooth disable_ertm=1 '';
    security.polkit.enable = true;

    programs.steam = {
        enable = true;
        remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
        dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
        localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
    hardware.steam-hardware.enable = true;
}
