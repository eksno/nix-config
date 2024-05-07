
{ config, pkgs, ... }:
{
    imports = [
        ../../shared/desktop/wayland/hyprland
        ./locale.nix
    ];

  users.users.lucy = {
    isNormalUser = true;
    description = "Lucy";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
  };

  services.displayManager.sddm.settings = {
    Autologin = {
        User = "lucy";
    };

    services.displayManager.sddm.settings = {
        Autologin = {
            User = "lucy";
        };
    };

  services.udev.extraRules = '' SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu" '';
   
  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    docker-compose
    wally-cli
  ];

    hardware.keyboard.zsa = {
        enable = true;
    };
}
