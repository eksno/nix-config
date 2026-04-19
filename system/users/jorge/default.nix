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

  dotfiles.username = "jorge";

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
  programs.ssh.extraConfig = ''
    IdentityAgent ~/.bitwarden-ssh-agent.sock
  '';
  services.xserver.xkb.layout = "us";
  console.useXkbConfig = true;
  virtualisation.docker.enable = true;
  security.polkit.enable = true;
}
