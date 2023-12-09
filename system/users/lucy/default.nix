
{ config, pkgs, ... }:
{
  imports = [
    ../../shared/desktop
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

  services.openssh = {
    enable = false;
  };

  environment.systemPackages = with pkgs; [

  ];
}
