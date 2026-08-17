---
type: reference
title: Offline XR/VR OSS source corpus at .research/
created: 2026-05-06
---

`/.research/` (gitignored, ~1.8 GB) holds full git clones of the OSS
projects we keep grepping during XR debugging. **Grep there before
re-fetching anything from the web** — it has every relevant repo at
known-good revisions, plus a curated `web/` notes directory.

## Layout

```
.research/
  src/      # full git clones (HEAD or pinned tag)
  kernel/   # linux kernel sparse-checkout (drivers/gpu/drm + DRM uAPI)
  web/      # curated web research notes (markdown)
  tools/    # placeholder
  INDEX.md  # full catalogue with per-repo "why it matters here" notes
```

`.research/INDEX.md` has the full table — start there before any deep
grep, it tells you which file in which repo to look at for a given
question.

## What's in src/ (highlights)

- **mesa** (505 MB, HEAD) — `src/vulkan/wsi/wsi_common_display.c` for
  every `SURFACE_LOST_KHR` emission, modifier negotiation, drmModeAddFB2
  call. ANV pass-through at `src/intel/vulkan/anv_wsi_display.c`.
- **monado** (52 MB, HEAD + `rayneo-mr2737` branch) — compositor in
  `src/xrt/compositor/main/` (`comp_window_direct_wayland.c`,
  `comp_target_swapchain.c`, `comp_renderer.c`). Settings/env in
  `comp_settings.c`. Rayneo driver in `src/xrt/drivers/rayneo/`
  (`rayneo-mr2737` branch only).
- **linux kernel** (651 MB, sparse to drm only) — i915 modeset, format
  modifiers, lease ioctls. UAPI in `include/uapi/drm/`.
- **Hyprland** (130 MB, tag `v0.54.3`) — `src/protocols/DRMLease.cpp`,
  `src/Compositor.cpp`. Matches what's deployed on lewis.
- **wlroots** + **aquamarine** — DRM lease backend semantics; aquamarine
  is Hyprland's actual KMS backend.
- **Vulkan-Loader** + **Vulkan-Headers** + **Vulkan-ValidationLayers** —
  spec text, surface lifetime, ICD dispatch.
- **OpenXR-SDK** + **OpenXR-SDK-Source** + **openxr-simple-example** —
  loader source + minimal reproducer.
- **wlx-overlay-s** + **wayvr-dashboard** — wayvr (renamed wlx-overlay-s)
  upstream lineage.
- **wivrn**, **gamescope**, **smithay** — alternate references for
  swapchain/format/lease handling.
- **wayland**, **wayland-protocols**, **wlr-protocols**,
  **hyprland-protocols** — protocol XML for `wp-drm-lease-v1` etc.
- **libdrm**, **drm_info** — userspace KMS API + the `drm_info` tool.
- **XRLinuxDriver**, **breezy-desktop**, **breezy-gnome** — Wheaney's
  closed-SDK shim and GNOME-based virtual display.

## What's in web/

Six markdown notes summarising key URLs (monado direct-mode docs,
Hyprland VR issues, Maister's `VK_KHR_display` blog, MR !2737
description, Vulkan storage-bit/scanout discussion, monado image-usage
smoking-gun annotation). One paragraph each — read these before
re-fetching the same URLs.

## When to refresh

Nothing is authoritative; re-clone freely. Practical triggers:

- Mesa / monado upstream lands a relevant fix (release notes mention
  `wsi_display`, swapchain usage, modifier negotiation).
- Hyprland or aquamarine ships a new tag and you want to compare
  against the deployed `v0.54.3`.
- You hit a bug not reproducible against HEAD — check INDEX.md for
  the recorded clone date and consider `git pull` in the relevant
  repo.

`.research/` is gitignored (commit `5b334b3`), so re-cloning won't
pollute the working tree.

## Anti-patterns

- Do NOT add web fetches for things already noted in `web/`.
- Do NOT `cat` whole files when grep can localise the question to a
  few lines — the corpus is big enough that token cost matters.
- Do NOT push fixes from this corpus upstream from inside the
  nix-config repo — patches we want to keep belong under
  `system/lib/xr/<pkg>/patches/` referenced from the matching
  `package.nix`.
