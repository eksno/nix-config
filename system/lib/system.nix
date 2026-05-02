{ config, pkgs, ... }:
{
    # Support flakes
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # Community binary caches — appended to cache.nixos.org so default trust
    # stays intact. Each saves source rebuilds for packages we actually use.
    nix.settings.extra-substituters = [
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://catppuccin.cachix.org"
    ];
    nix.settings.extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
    ];

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
    system.stateVersion = "25.05"; # Did you read the comment?
}
