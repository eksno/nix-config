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
    dns = "none";
    # Disable NM’s Wi-Fi powersave features
    # wifi = {
    #   powersave = false;
    #   scanRandMacAddress = false;
    # };
  };

  # One-shot service to kill any lingering hardware power-save
  # systemd.services.disable-wifi-powersave = {
  #   description = "Disable Wi-Fi power management";
  #   after = [ "network.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = "${pkgs.iw}/bin/iw dev wlo1 set power_save off";
  #     RemainAfterExit = true;
  #   };
  # };
  #
  ################################################################
  # DNS
  ################################################################
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

}
