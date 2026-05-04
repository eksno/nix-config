{ pkgs, ... }:

let
  xrLinuxDriver = pkgs.callPackage ./package.nix { };
in
{
  environment.systemPackages = [ xrLinuxDriver ];

  # Picks up /lib/udev/rules.d/*.rules from the package — Rayneo (1bbb),
  # XREAL, Viture, Rokid vendor IDs + uinput static_node + uaccess tags.
  services.udev.packages = [ xrLinuxDriver ];

  # Make sure /dev/uinput is reachable for the driver. The udev rule
  # OPTIONS+="static_node=uinput" handles node creation before any plug
  # event, but the kernel module still needs to be loaded.
  boot.kernelModules = [ "uinput" ];

  # Per-user systemd unit. Driver writes log + state under XDG dirs, so
  # leaving HOME/XDG to defaults is correct here.
  systemd.user.services.xr-driver = {
    description = "XR user-space driver (Rayneo / XREAL / Viture / Rokid)";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${xrLinuxDriver}/bin/xrDriver";
      Restart = "always";
      RestartSec = 2;
    };
  };
}
