
{ config, pkgs, ... }:
{
    imports = [
        ../../shared/desktop/wayland/hyprland
        ./locale.nix
    ];

    users.users.eksno = {
        isNormalUser = true;
        description = "Jonas Lindberg";
        extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
        openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII4AP87WBXD5W+VrUSNVNSc3UugdxtaMqenVlwApZAcf eksno" # content of authorized_keys file
        # note: ssh-copy-id will add user@your-machine after the public key
        # but we can remove the "@your-machine" part
        ];
    };

    services.xserver.xkb.layout = "us";
    services.xserver.xkb.variant = "dvp";
    console.useXkbConfig = true;
    
    services.displayManager.sddm.settings.Autologin.User = "eksno";

    services.openssh.enable = true;

    virtualisation.docker.enable = true;

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [

    ];

    environment.systemPackages = with pkgs; [
        docker-compose
        xorg.xmodmap
        xorg.xkbcomp
    ];

    programs.steam = {
        enable = true;
        remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
        dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
        localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
}
