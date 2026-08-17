{ wayvr }:

# WayVR with locally applied patches for Mesa anv (Intel) compatibility.
#
# - text-atlas-larger-initial-size.patch — bumps wgui's text glyph atlas
#   initial size from 256 to 2048 so the buggy atlas-grow path is never
#   triggered. The grow path in `wgui/src/renderer_vk/text/text_atlas.rs`
#   crashes on Mesa anv when the dashboard first pushes glyphs past 256x256
#   (suspected: in-flight command buffers still hold the old image_view via
#   descriptor while build_and_execute_now() submits the copy without
#   waiting for queue idle). 2048x2048 RGBA8 = 16 MiB up-front; cheap.
#
# - curved-arc-layout.patch — Phase 4B: distribute screens across a
#   horizontal arc around the user instead of stacking them all at
#   z=-0.5. Each screen at index i of n gets θ_i = (i - (n-1)/2) *
#   SPACING, position (R sin θ, 0, -R cos θ), rotation
#   from_rotation_y(-θ) so its -Z faces the user. Defaults: R=0.6m,
#   SPACING=0.6 rad (~34°). Single-screen sessions fall back to the
#   legacy (0, 0, -0.5) anchor.
#
# - ipc-telemetry-and-layout.patch — the IPC surface the Glasses cockpit
#   app needs: WlxInputState gains hmd_rot + fps, and two new packets
#   (WlxScreenList / WlxScreenPlace) report and set each screen's
#   yaw/pitch/distance/scale/curvature. Bumps PROTOCOL_VERSION 3 -> 4.
#   Also fixes an upstream copy/paste bug where the right pointer's
#   position was read from pointers[0].
#
# - dmabuf-capture-on-single-queue-gpus.patch — the big FPS fix. On a GPU
#   with only one queue family (Intel Meteor Lake / anv), wayvr routes
#   capture through MainThreadWlxCapture, which handed wlr_screencopy a
#   no-op DMA exporter; screencopy falls back to SHM for the whole
#   session when the exporter yields no buffer, so every frame was a full
#   framebuffer memcpy plus a blocking upload on the render thread
#   (~30 fps on a 60 Hz output). Only the SHM paths actually need the
#   main thread — DMA-buf frames resolve to a pre-allocated Arc<ImageView>
#   with no queue work — so the callback now splits: DMA-buf finishes on
#   the capture thread, SHM still defers.
#
# - keyboard-optional-on-spawn.patch — adds `keyboard_on_spawn` (default
#   true) so the virtual keyboard can be left out of the session when a
#   real keyboard is in reach.
#
# - ipc-screen-visibility.patch — WlxScreenSetVisible packet +
#   `wayvrctl screen-show/screen-hide`. Wraps OverlayTask::ToggleOverlay
#   (EnsureOn/EnsureOff) so the cockpit can show several screens in the
#   current overlay set at once instead of one-screen-per-set.
#
# - recenter-include-pitch.patch — adds `recenter_includes_pitch`
#   config (default off). When on, Recenter matches gaze pitch as well
#   as yaw so screens land centred where you're looking, instead of
#   only rotating around you at the old height. Roll never tilts.
#
# Patches apply against the v26.7.1 source nixpkgs pins. If the version
# bumps, re-verify the patch context (26.2.1 -> 26.7.1 moved the wayland
# screen-creation loop body and its call site; curved-arc-layout.patch
# was regenerated for it).

# Keep pname = "wayvr" so the vendor-staging derivation name doesn't
# change (vendor staging takes ~20 min of network fetch on first run
# because nix re-fetches the entire Cargo.lock dep set under the new
# name, even though contents match upstream). Adding patches only
# invalidates the build phase, not the vendor — keep that fast.
wayvr.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./patches/text-atlas-larger-initial-size.patch
    ./patches/curved-arc-layout.patch
    ./patches/screencopy-mainthread-fd-use-after-close.patch
    ./patches/ipc-recenter-command.patch
    ./patches/ipc-telemetry-and-layout.patch
    ./patches/dmabuf-capture-on-single-queue-gpus.patch
    ./patches/keyboard-optional-on-spawn.patch
    ./patches/ipc-screen-visibility.patch
    ./patches/recenter-include-pitch.patch
  ];
})
