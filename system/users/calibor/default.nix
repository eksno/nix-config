
{ config, pkgs, ... }:
{
  imports = [
    ../../shared
  ];

  users.users.calibor = {
    isNormalUser = true;
    description = "Daniel Aanensen";
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };

  services.xserver.displayManager.sddm.settings.AutoLogin.User = "calibor";

  environment.systemPackages = with pkgs; [

  ]
}
