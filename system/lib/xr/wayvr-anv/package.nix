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
# Patches apply against the v26.2.1 source nixpkgs pins. If the version
# bumps, re-verify the patch context.

wayvr.overrideAttrs (old: {
  pname = "wayvr-anv";
  patches = (old.patches or [ ]) ++ [
    ./patches/text-atlas-larger-initial-size.patch
  ];
})
