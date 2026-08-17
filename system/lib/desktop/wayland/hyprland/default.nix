{ config, lib, pkgs, ... }:
{
  imports = [
    ./..
  ];

  programs.hyprland.enable = true;
  programs.uwsm.enable = true;

  # Drop CAP_SYS_NICE from the Hyprland wrapper. Default nixpkgs sets
  # `security.wrappers.Hyprland.capabilities = "cap_sys_nice+ep"` so Hyprland
  # can self-promote to SCHED_RR. Hyprland then raises CAP_SYS_NICE into its
  # AMBIENT set, so every descendant (kitty, fish, chrome, …) ends up with
  # CAP_SYS_NICE in cap_permitted. xdg-desktop-portal runs as a plain user
  # systemd service with cap_effective=0, so the kernel's cap_ptrace_access_check
  # (`cap_issubset(child.permitted, caller.effective)`) returns -EPERM when the
  # portal opens /proc/<caller>/root to detect flatpak. xdp 1.20.4 treats this
  # as fatal and replies "Portal operation not allowed: Unable to open /proc/X/root"
  # → file-open dialogs never appear. See upstream issue #1691 and FIXES.md.
  security.wrappers.Hyprland.capabilities = lib.mkForce "";

  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;

    settings = {
      Autologin = {
        Session = "hyprland-uwsm.desktop";
      };
    };

    enableHidpi = true;

    wayland = {
      enable = true;
    };
  };

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-gtk
    pkgs.xdg-desktop-portal-hyprland
  ];
}
