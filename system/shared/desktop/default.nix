{ config, pkgs, ... }:
{
  imports = [
    ../headless
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "electron-25.9.0"
  ];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
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

  hardware = {
    opengl.enable = true;
  };
xdg.portal.config.common.default = "*";
}
