
{ config, pkgs, ... }:
{
    imports = [
        ../../shared/desktop/wayland/hyprland
        ./locale.nix
    ];

  users.users.teto = {
    isNormalUser = true;
    description = "Teto";
    extraGroups = [ "networkmanager" "wheel" "video"];
  };

  environment.systemPackages = with pkgs; [
    docker-compose
    wally-cli
  ];

}
