
{ config, pkgs, ... }:
{
  imports = [
    ../../shared
  ];

  users.users.jorge = {
    isNormalUser = true;
    description = "Jorge Lewis";
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };

  services.udisks2.enable = true;
  services.devmon.enable = true;

  services.xserver.displayManager.sddm.settings.AutoLogin.User = "jorge";
}
