{ config, pkgs, ... }:
{
  # This automatically performs a garbage collection of old Nix store generations
  nix.gc.automatic = true;

  # This enables a periodically executed systemd service named nixos-upgrade.service.
  # If the allowReboot option is false, it runs nixos-rebuild switch --upgrade to
  # upgrade NixOS to the latest version in the current channel.
  # (To see when the service runs, see systemctl list-timers.)
  system.autoUpgrade.enable = true;

  # If allowReboot is true, then the system will automatically reboot if the new
  # generation contains a different kernel, initrd or kernel modules.
  system.autoUpgrade.allowReboot = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "unstable"; # Did you read the comment?
}
