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

  users.users.eksno = {
    isNormalUser = true;
    description = "Jonas Lindberg";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
  };

  services.displayManager.sddm.settings.Autologin.User = "eksno";
  services.openssh.enable = true;
  programs.ssh.extraConfig = ''
    IdentityAgent ~/.bitwarden-ssh-agent.sock
  '';
  services.xserver.xkb.layout = "us";
  console.useXkbConfig = true;
  virtualisation.docker.enable = true;
  security.polkit.enable = true;
}
