{ pkgs, ... }:

# Hyprland-side breezy stack: WayVR (OpenXR overlay) on top of Monado
# (with the rayneo MR !2737 patches). Open-source replacement for the
# productivity-tier paywalled SHM that the breezy-gnome stack depends on.
#
# Architecture:
#   xr-driver  (mouse mode only — disable SHM writer for this session)
#   monado-service  (OpenXR runtime, Rayneo driver enumerates head pose)
#   wayvr --openxr --show  (composes desktop captures as world-locked panels)
#
# Capture path: WayVR talks to xdg-desktop-portal-hyprland via pipewire,
# which uses wlr-screencopy under the hood. No fork required.
#
# Phase 2 deliverable: WayVR launches against Monado, shows passthrough +
# at least one captured Hyprland output as a world-locked panel.

let
  monadoRayneo = pkgs.callPackage ../monado-rayneo/package.nix { };
  wayvrAnv = pkgs.callPackage ../wayvr-anv/package.nix { };
  breezyHyprland = pkgs.callPackage ./launcher.nix {
    inherit monadoRayneo;
    inherit (pkgs) hyprland;
    wayvr = wayvrAnv;
  };
in
{
  environment.systemPackages = [
    wayvrAnv
    breezyHyprland
  ];

  # Point the OpenXR loader at our patched Monado. Without this, any OpenXR
  # client (WayVR included) errors out with "no active runtime" at startup.
  # The loader checks $XR_RUNTIME_JSON first, then ~/.config/openxr/1/
  # active_runtime.json, then /etc/xdg/openxr/1/active_runtime.json — env
  # var is the most deterministic.
  environment.variables.XR_RUNTIME_JSON =
    "${monadoRayneo}/share/openxr/1/openxr_monado.json";
}
