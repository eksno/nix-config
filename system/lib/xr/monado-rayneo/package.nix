{
  monado,
  fetchFromGitLab,
}:

# Monado with Stanislav Aleksandrov's Rayneo driver from MR !2737
# (https://gitlab.freedesktop.org/monado/monado/-/merge_requests/2737).
#
# Stock Monado does not enumerate the Rayneo Air 4 Pro (USB 1bbb:af50) —
# the xreal_air driver only matches XREAL VID 0x3318. MR !2737 adds a
# dedicated `rayneo` driver tested against Air 4 Pro hardware.
#
# Strategy: replace `src` with the MR head. The MR is purely additive
# (new src/xrt/drivers/rayneo/ subtree + meson wiring), so any existing
# nixpkgs patches against monado.git/main should still apply cleanly.
#
# Rev pinned to MR head as of 2026-05-05. Bump when the MR moves.
monado.overrideAttrs (old: {
  pname = "monado-rayneo";
  version = "unstable-2026-05-05-mr2737";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "monado";
    repo = "monado";
    rev = "4b8d4a81328e8240a180aad6f70337ac691d9cbf";
    hash = "sha256-otpOpJDchRjMuxrG/6J9MwyRb40LgfftPb0DcKpRLe8=";
  };

  # Nixpkgs carries `monado-cylinder-aspectRatio.patch` as a backport against
  # stable monado 25.1.0. The MR !2737 branch is post-25.1 and already includes
  # the upstream commit that patch backports — applying it again fails with
  # "Reversed (or previously applied) patch detected." Filter it out by name;
  # keep any other patches nixpkgs adds in the future.
  #
  # Locally added:
  # - comp-renderer-scanout-compatible-tiling.patch — pairs
  #   COLOR_ATTACHMENT_BIT with STORAGE_BIT on the compute-path swapchain so
  #   Mesa anv picks scanout-compatible tiling for direct WSI display. See
  #   patches/comp-renderer-scanout-compatible-tiling.patch for details.
  # - comp-renderer-surface-lost-retry.patch — bounded retry on
  #   VK_ERROR_SURFACE_LOST_KHR in renderer_acquire_swapchain_image and
  #   renderer_present_swapchain_image. Sidesteps the transient kernel EBUSY
  #   on monado's first DRM_IOCTL_MODE_ATOMIC, which Mesa flattens to
  #   SURFACE_LOST. See memory/xr-mesa-anv-ebusy-on-first-present.md.
  patches =
    builtins.filter (
      p: !(builtins.match ".*monado-cylinder-aspectRatio.*" (toString p) != null)
    ) (old.patches or [ ])
    ++ [
      ./patches/comp-renderer-scanout-compatible-tiling.patch
      ./patches/comp-renderer-surface-lost-retry.patch
    ];
})
