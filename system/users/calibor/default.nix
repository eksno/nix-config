
{ config, pkgs, ... }:
{
  users.users.calibor = {
    isNormalUser = true;
    description = "Daniel Aanensen";
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };
}