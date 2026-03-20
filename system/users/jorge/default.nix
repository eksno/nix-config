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
    ../../lib/power-mode
    ./programs
    ./dev
    ./locale.nix
    ./theme.nix
  ];

  users.users.jorge = {
    isNormalUser = true;
    description = "Jorge Lewis";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
  };

  services.displayManager.sddm.settings.Autologin.User = "jorge";
  services.openssh.enable = true;
  services.xserver.xkb.layout = "us";
  console.useXkbConfig = true;
  virtualisation.docker.enable = true;
  security.polkit.enable = true;
}
