
{ config, pkgs, ... }:
{
  imports = [
    ../../shared/desktop
  ];

  users.users.eksno = {
    isNormalUser = true;
    description = "Jonas Lindberg";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
  };

  services.xserver.layout = "us";
  services.xserver.xkbVariant = "dvp";
  services.xserver.displayManager.sddm.settings.Autologin.User = "eksno";

  services.openssh.enable = true;

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
