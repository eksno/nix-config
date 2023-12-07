
{ config, pkgs, ... }:
{
  imports = [
    ../../shared
  ];

  time.timeZone = "Asia/Hong_Kong";

  users.users.jorge = {
    isNormalUser = true;
    description = "Jorge Lewis";
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };


  services.udisks2.enable = true;
  services.devmon.enable = true;

  virtualisation.docker.enable = true;

  services.xserver.displayManager.sddm.settings.AutoLogin.User = "jorge";
}
