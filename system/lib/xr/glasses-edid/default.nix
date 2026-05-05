{ pkgs, lib, ... }:

# Patches the kernel's view of the Rayneo Air 4 Pro EDID so wlroots/Hyprland
# treat the glasses as a non-desktop output and advertise the connector via
# wp-drm-lease-v1. Without this, monado can't take a direct DRM lease and
# falls back to Wayland-windowed mode where SBS rendering goes wrong.
#
# The shipped EDID under xr/edid/glasses-nondesktop.bin is the original
# captured EDID with a Microsoft HMD VSDB inserted into the CTA-861
# extension block (see xr/edid/patch_glasses_edid.py). Linux's
# `cea_db_is_microsoft_vsdb` recognizes the OUI 0x5C 0x12 0xCA + 21-byte
# payload and sets `connector.non_desktop = true` on parse.
#
# Connector name is per-host (DP alt-mode connector path differs by laptop).
# On lewis the glasses come up at DP-2; verify post-reboot via:
#   cat /sys/class/drm/card1-DP-2/non_desktop   # should print 1
#   hyprctl monitors all | grep SmartGlasses    # should NOT appear (Hyprland
#                                                 skips non-desktop outputs)

let
  edidFirmware = pkgs.runCommand "rayneo-air4pro-edid-firmware" { } ''
    mkdir -p $out/lib/firmware/edid
    cp ${../../../../xr/edid/glasses-nondesktop.bin} \
       $out/lib/firmware/edid/rayneo-air4pro-glasses.bin
  '';
in
{
  hardware.firmware = [ edidFirmware ];

  # `drm.edid_firmware=<connector>:<path>` — the path is relative to
  # /lib/firmware. The connector name comes from /sys/class/drm/card*-NAME.
  # Hardcoded to DP-2 (lewis); copy this module and adjust if porting.
  boot.kernelParams = [
    "drm.edid_firmware=DP-2:edid/rayneo-air4pro-glasses.bin"
  ];
}
