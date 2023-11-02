
{ config, pkgs, ... }:
{
  imports = [
    ../../shared
  ];

  users.users.eksno = {
    isNormalUser = true;
    description = "Jonas Lindberg";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
  };

  virtualisation.docker.enable = true;
  environment.systemPackages = with pkgs; [
    wayvnc
    docker-compose
  ];

  services.openssh = {
    enable = true;
  };
}
