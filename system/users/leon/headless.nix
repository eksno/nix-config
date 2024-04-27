
{ config, pkgs, ... }:
{
    imports = [
        ../../shared/headless
        ./locale.nix
    ];

    users.users.nixos = {
        isNormalUser = true;
        description = "Leon Nilsson";
        extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
    };

    services.openssh = {
        enable = true;
    };

    virtualisation.docker.enable = true;

    environment.systemPackages = with pkgs; [
        docker-compose
    ];
}
