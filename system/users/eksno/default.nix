
{ config, pkgs, ... }:
{
    imports = [
        ../../shared/desktop/wayland/hyprland
        ./locale.nix
        ./steamcontroller.nix
    ];

    users.users.eksno = {
        isNormalUser = true;
        description = "Jonas Lindberg";
        extraGroups = [ "networkmanager" "wheel" "video" "docker" "input" "uinput" "audio" "video" "pulse" "storage" "network" "netdev" "games" ];
    };

    services.xserver.xkb.layout = "us";
    services.xserver.xkb.variant = "dvp";
    console.useXkbConfig = true;

    services.kanata.enable = true;
    services.kanata.keyboards.main = {
        config = ''
            (defsrc
                esc
                caps
            )

            (defalias
                noesc ()
                cec (tap-hold 100 100 esc lctrl)
            )

            (deflayer base
                @noesc
                @cec
            )
        '';
    };
    
    services.displayManager.sddm.settings.Autologin.User = "eksno";

    services.openssh.enable = true;

    virtualisation.docker.enable = true;

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [

    ];

    environment.systemPackages = with pkgs; [
        lm_sensors
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
