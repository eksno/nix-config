
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



  users.users.teto = {
    isNormalUser = true;
    description = "Teto";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
  };

    services.displayManager.sddm.settings = {
        Autologin = {
            User = "teto";
        };
    };

  services.udev.extraRules = '' SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu" '';
  environment.systemPackages = with pkgs; [
    docker-compose
    wally-cli
  ];

}
