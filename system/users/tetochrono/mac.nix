
{ config, pkgs, ... }:
{
  imports = [
    ../../shared/headless
  ];

  users.users.nixos = {
    isNormalUser = true;
    description = "Daniel Aanensen";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
  };

  services.openssh = {
    enable = false;
  };


  environment.systemPackages = with pkgs; [

  ];
}
