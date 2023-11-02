{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix  # Include the results of the hardware scan.
    ../../device/nvidia.nix  # Nvidia Support
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Setup keyfile
  boot.initrd.secrets = {
    "/crypto_keyfile.bin" = null;
  };

  # Enable swap on luks
  boot.initrd.luks.devices."luks-589df6f1-93ce-4143-a774-4d78eb0800a8".device = "/dev/disk/by-uuid/589df6f1-93ce-4143-a774-4d78eb0800a8";
  boot.initrd.luks.devices."luks-589df6f1-93ce-4143-a774-4d78eb0800a8".keyFile = "/crypto_keyfile.bin";

  networking.hostName = "verse"; # Define your hostname.
 } 
