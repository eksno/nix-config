
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

  services.xserver.displayManager.sddm.settings = {
    Autologin = {
        User = "eksno";
    };
  };

  services.openssh = {
    enable = true;
  };

  virtualisation.docker.enable = true;

  environment.sessionVariables = rec {
    HYPRLAND_PROFILE = "vnc";
  };

  environment.systemPackages = with pkgs; [
    docker-compose
    wayvnc
  ];
}
