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

  # NetworkManager-wait-online gated the whole graphical session for 60s.
  # `nm-online -s` blocks until NM reports STARTUP=complete, but the
  # auto-created `p2p-dev-wlo1` (wifi-p2p) device never leaves `disconnected`,
  # so NM stays at STARTUP=started and the unit always burns its full timeout
  # and then fails.
  #
  # The cost is not just a failed unit. It gates:
  #   NetworkManager-wait-online -> network-online.target -> docker.service
  #     -> multi-user.target -> graphical.target
  # and uwsm refuses to launch Hyprland until graphical.target is reached
  # ("graphical.target is queued for start, waiting for 60s..."), so the
  # login handoff sat on a blank screen for the full minute before timing
  # out and starting the compositor anyway.
  #
  # Only docker.service and nixos-upgrade.service want network-online.target
  # here, and neither needs to block the desktop. On a laptop that roams
  # between networks, blocking boot on connectivity is wrong regardless.
  systemd.services.NetworkManager-wait-online.enable = false;

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

}
