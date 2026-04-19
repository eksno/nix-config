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

  dotfiles.username = "eksno";

  users.users.eksno = {
    isNormalUser = true;
    description = "Jonas Lindberg";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "ydotool" # access to /run/ydotoold/socket for keystroke injection
    ];
  };

  services.displayManager.sddm.settings.Autologin.User = "eksno";
  services.openssh.enable = true;
  programs.ssh.extraConfig = ''
    Host 144.76.155.176
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null

    IdentityAgent ~/.bitwarden-ssh-agent.sock
  '';
  services.xserver.xkb.layout = "us";
  console.useXkbConfig = true;
  virtualisation.docker.enable = true;
  security.polkit.enable = true;

  # ydotool injects keystrokes via /dev/uinput so Electron/Chromium apps
  # (which ignore virtual_keyboard_unstable_v1 that wtype uses) receive them.
  programs.ydotool.enable = true;
  environment.sessionVariables.YDOTOOL_SOCKET = "/run/ydotoold/socket";
}
