{ config, pkgs, ... }:
{
    imports = [  # Do not import from ../../shared here. This is just hardware/device related.
        ./hardware-configuration.nix  # Include the results of the hardware scan.
    ];

    services.xserver.exportConfiguration = true;

    # Bootloader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    hardware.nvidia.prime = {
		offload = {
			enable = true;
			enableOffloadCmd = true;
		};

		# Make sure to use the correct Bus ID values for your system!
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
    };

    networking.hostName = "werse"; # Define your hostname.
 } 
