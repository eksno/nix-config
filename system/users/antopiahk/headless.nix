
{ config, pkgs, ... }:
{
  imports = [
    ../../shared/headless
  ];

  users.users.nixos = {
    isNormalUser = true;
    description = "Jorge Lewis";
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
