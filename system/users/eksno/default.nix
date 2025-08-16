{
  system,
  inputs,
  config,
  pkgs,
  ...
}:
{

  imports = [
    ../../lib/desktop/wayland/hyprland
    ./programs
    ./dev
    ./locale.nix
    ./theme.nix
  ];

  users.users.eksno = {
    isNormalUser = true;
    description = "Jonas Lindberg";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
  };

  services.tlp.enable = true;
  services.displayManager.sddm.settings.Autologin.User = "eksno";
  services.openssh.enable = true;
  services.xserver.xkb.layout = "us";
  console.useXkbConfig = true;
  virtualisation.docker.enable = true;
  security.polkit.enable = true;
}
