
{ config, pkgs, ... }:
{
  imports = [
    ../../shared
  ];

  users.users.lucy = {
    isNormalUser = true;
    description = "Lucy";
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };

  services.xserver.displayManager.sddm.settings = {
    Autologin = {
        User = "lucy";
    };
  };

  environment.systemPackages = with pkgs; [

  ];
}
