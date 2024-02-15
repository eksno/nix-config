
{ config, pkgs, ... }:
{
  imports = [
    ../../shared/desktop/x11/i3
  ];

  users.users.eksno = {
    isNormalUser = true;
    description = "Jonas Lindberg";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII4AP87WBXD5W+VrUSNVNSc3UugdxtaMqenVlwApZAcf eksno" # content of authorized_keys file
      # note: ssh-copy-id will add user@your-machine after the public key
      # but we can remove the "@your-machine" part
    ];
  };

  services.xserver.xkb.layout = "us";
  services.xserver.xkb.variant = "dvp";
  services.xserver.displayManager.sddm.settings.Autologin.User = "eksno";

  services.openssh.enable = true;

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
