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
    ./skip-scipy-test-deps.nix
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

  # No autologin: typing the password at SDDM lets pam_gnome_keyring unlock
  # the login keyring. Autologin left it locked, and the boot-time unlock
  # dialog repeatedly hung Chrome/Discord (see FIXES.md 2026-10-17).
  services.displayManager.defaultSession = "hyprland-uwsm";
  services.openssh.enable = true;
  programs.ssh.extraConfig = ''
    IdentityAgent ~/.bitwarden-ssh-agent.sock
  '';
  services.xserver.xkb.layout = "us";
  console.useXkbConfig = true;
  virtualisation.docker.enable = true;
  security.polkit.enable = true;
}
