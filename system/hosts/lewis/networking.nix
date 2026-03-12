{ config, pkgs, ... }:

{
  ################################################################
  # System Packages
  ################################################################
  environment.systemPackages = with pkgs; [
    # Wi-Fi debugging & tools
    iw
    mtr
    iperf3
    dnsutils
    ldns
    aria2
    socat
    nmap
    ipcalc

    # Regulatory database & helper
    wireless-regdb
  ];

  ################################################################
  # Kernel, Firmware & Modules
  ################################################################
  # Pull in all firmware (including iwlwifi & Realtek)
  hardware.enableAllFirmware = true;

  # Ensure the modules we need get loaded
  boot.kernelModules = [
    "iwlwifi"
    "rtw89_pci"
  ];

  # Pass regulatory domain to cfg80211
  boot.kernelParams = [
    "cfg80211.regdom=NO"
  ];

  ################################################################
  # Networking / NetworkManager
  ################################################################
  networking.networkmanager = {
    enable = true;
    # "default" lets DHCP-provided DNS work (needed for captive portals)
    # while nameservers below are appended as fallback
    dns = "default";
  };

  ################################################################
  # Tailscale
  ################################################################
  services.tailscale.enable = true;

  ################################################################
  # DNS (appended after DHCP-provided servers)
  ################################################################
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  ################################################################
  # Local Hosts
  ################################################################
  networking.hosts = {
    "127.0.0.1" = [ "local.openclaw.zone" "local.echoai.zone" ];
  };

}
