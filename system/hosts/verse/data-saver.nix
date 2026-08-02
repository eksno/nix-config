{ config, lib, pkgs, ... }:

{
  # Auto-engage data-saving measures while the "verse" phone hotspot is the
  # uplink, and lift them again on any other network. NetworkManager runs this
  # on every connect/disconnect, so the logic re-evaluates the full active
  # connection list each time (idempotent both ways).
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "verse-data-saver" ''
        PATH=${lib.makeBinPath (with pkgs; [ systemd networkmanager gnugrep coreutils ])}

        case "$2" in
          up|down) ;;
          *) exit 0 ;;
        esac

        if nmcli -t -f NAME connection show --active | grep -qx "verse"; then
          # -- Engage: on the mobile hotspot --
          # Pin the profile as metered (not just "guessed") so metered-aware
          # apps back off; idempotent check avoids rewriting the profile.
          [ "$(nmcli -g connection.metered connection show verse)" = "yes" ] \
            || nmcli connection modify verse connection.metered yes || true

          # Daily nixos-upgrade pulls 1-3 GB from unstable per run. Masking is
          # not possible on NixOS (the unit in /etc/systemd/system is a
          # nix-managed symlink systemctl refuses to shadow), so stop both the
          # timer and any in-flight service; this script re-runs on every
          # network event, so a reboot on the hotspot re-stops them on connect.
          systemctl stop nixos-upgrade.timer 2>/dev/null || true
          systemctl stop nixos-upgrade.service 2>/dev/null || true

          # Tailscale's DERP keepalives burn data around the clock.
          systemctl stop tailscaled.service 2>/dev/null || true

          touch /run/data-saver
        else
          # -- Disengage: on any other (or no) network --
          systemctl start nixos-upgrade.timer 2>/dev/null || true
          systemctl start tailscaled.service 2>/dev/null || true
          rm -f /run/data-saver
        fi
      '';
    }
  ];
}
