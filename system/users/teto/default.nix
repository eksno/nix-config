
{ config, pkgs, ... }:
{
  imports = [
    ../../shared/headless
  ];

  users.users.teto = {
    isNormalUser = true;
    description = "teto";
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };


  services.openssh = {
    enable = true;
  };
   

  environment.systemPackages = with pkgs; [

  ];

}
