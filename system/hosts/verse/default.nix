{ config, pkgs, ... }:
{
  imports = [  # Do not import from ../../shared here. This is just hardware/device related.
    ./hardware-configuration.nix  # Include the results of the hardware scan.
    ../../device/nvidia.nix  # Nvidia Support
    ./input.nix
  ];

  services.xserver.exportConfiguration = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 42;

  # Setup keyfile
  boot.initrd.secrets = {
    "/crypto_keyfile.bin" = null;
  };

  # Enable swap on luks
  boot.initrd.luks.devices."luks-589df6f1-93ce-4143-a774-4d78eb0800a8".device = "/dev/disk/by-uuid/589df6f1-93ce-4143-a774-4d78eb0800a8";
  boot.initrd.luks.devices."luks-589df6f1-93ce-4143-a774-4d78eb0800a8".keyFile = "/crypto_keyfile.bin";

  networking.hostName = "verse"; # Define your hostname.
 } 
