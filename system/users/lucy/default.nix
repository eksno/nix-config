
{ config, pkgs, ... }:
{
  imports = [
    ../../shared
  ];

  users.users.lucy = {
    isNormalUser = true;
    description = "Daniel Aanensen";
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };

  services.xserver.displayManager.sddm.settings.AutoLogin.User = "lucy";

  environment.systemPackages = with pkgs; [

  ];
}
