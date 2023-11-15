
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
}
