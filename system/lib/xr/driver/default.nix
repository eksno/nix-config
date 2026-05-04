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
  #
  # ExecStartPre seeds ~/.config/xr_driver/config.ini from the repo template
  # before each launch. The driver mutates this file at runtime (e.g., flips
  # `disabled=true` when no headset is plugged), so a passive symlink would
  # either dirty the repo or fail to write — installing a fresh copy each
  # start gives us a stable contract: repo wins on restart, runtime tweaks
  # are ephemeral.
  systemd.user.services.xr-driver = {
    description = "XR user-space driver (Rayneo / XREAL / Viture / Rokid)";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/install -Dm644 ${../../../../dotfiles/default/xr_driver/config.ini} %h/.config/xr_driver/config.ini";
      ExecStart = "${xrLinuxDriver}/bin/xrDriver";
      Restart = "always";
      RestartSec = 2;
    };
  };
}
