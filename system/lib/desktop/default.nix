{
  config,
  catppuccin,
  pkgs,
  ...
}:
{
  imports = [
    ../fish.nix
    ../fonts.nix
    ../system.nix
  ];

  programs.tmux.enable = true;

  # keyring
  services.gnome.gnome-keyring.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  services.pulseaudio.support32Bit = true;

  hardware.graphics.enable32Bit = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Support ntfs
  boot.supportedFilesystems = [ "ntfs" ];

  # links /libexec from derivations to /run/current-system/sw
  environment.pathsToLink = [ "/libexec" ];

  xdg.portal.config.common.default = "*";

  # Theming
  catppuccin.flavor = "mocha";
  catppuccin.enable = true;
}
