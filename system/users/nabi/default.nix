
{ config, pkgs, ... }:
{
    imports = [
        ../../shared/desktop/wayland/hyprland
        ./locale.nix
    ];

    programs = {
        steam = {
            enable = true;
        };
    };



  users.users.nabi = {
    isNormalUser = true;
    description = "nabi";
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };

    services.displayManager.sddm.settings = {
        Autologin = {
            User = "nabi";
        };
    };

  environment.systemPackages = with pkgs; [
  ];

}
