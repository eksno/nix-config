
{ config, pkgs, ... }:
{
  imports = [
  ];

  users.users.nixos = {
    isNormalUser = true;
    description = "Jonas Lindberg";
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
