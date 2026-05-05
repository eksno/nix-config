# Phase 3.5 — Decision document (not an implementation plan)

Started: 2026-05-06
Status: **Decision pending — Jorge picks (or shelves) before next code attempt**

## Why this is a decision doc, not a plan

Phase 3 is architecturally complete: EDID override flips
`non_desktop=1`, wlroots advertises the connector via
`wp-drm-lease-v1`, monado takes the lease, OpenXR session reaches
FOCUSED with the real Rayneo head device. **But the glasses are still
black** because the first `vkQueuePresentKHR` after surface creation
fails with `VK_ERROR_SURFACE_LOST_KHR`.

Independent reproduction confirms the failure is in Mesa's `anv` driver
on Intel Arc, not in monado, EDID, lease handling, or any project code:

- `vulkaninfo` warns: `ICD for selected physical device does not export
  vkGetPhysicalDeviceDisplayPlanePropertiesKHR`
- `vkcube --wsi display` fails with "Cannot find any display!" on both
  Intel Arc and llvmpipe — no monado involved

Full root cause + reproduction recipe: `memory/xr-mesa-anv-display-gap.md`.

This document enumerates the four forward options, the honest cost of
each, and the signal that would make each one the right choice. **No
code attempt should start until Jorge picks one (or explicitly shelves
the whole effort).** Per the new stop-the-loop rule in `CLAUDE.md`,
randomly picking one and seeing what happens is exactly the failure
mode we're trying to stop.

## The four options

### Option A — Patch Mesa anv to implement display plane functions

**What**: Implement `vkGetPhysicalDeviceDisplayPlanePropertiesKHR` and
its sibling functions in `src/intel/vulkan/` of upstream Mesa. Submit
upstream MR. Wait for merge + nixpkgs bump, OR carry as a local
overlay.

**Cost**: Multi-week minimum. Requires reading anv internals, the
xe / i915 KMS interfaces, and the Vulkan WSI display extension spec.
Submitting upstream means review cycles. Carrying locally means
maintenance burden every Mesa bump.

**Risk**: High. The reason this isn't already implemented is probably
that no one with anv expertise has needed display-plane direct mode.
There may be architectural blockers in anv's swapchain code we don't
know about until we hit them.

**Unblocks**: This + everything downstream. Direct-mode VR rendering
on Intel Arc with any OpenXR runtime. Probably useful to other Mesa
users too.

**Right choice if**: Jorge wants to invest in the Linux VR ecosystem
long-term, has time to spend on a real upstream contribution, and is
OK with months not weeks.

**Stop-the-loop pre-commitment**: If after 2 weeks of focused effort
no working `vkcube --wsi display` on Intel Arc, halt and reconsider.

### Option B — Stay in Wayland-windowed mode and solve the SBS rendering

**What**: Revert (or coexist with) the EDID override. Let monado fall
back to Wayland-windowed compositor mode (Phase 2 baseline). Solve the
remaining problems:

1. Put the glasses into 3D SBS mode via the rayneo HID toggle
   (the rayneo driver knows how — we'd expose / call the toggle)
2. Get a 3840x1080 mode advertised on the connector (custom Hyprland
   monitor entry, or modeline injection — the EDID may or may not
   already include this mode)
3. Hyprland-fullscreen monado's Wayland window onto the glasses
   output specifically
4. Fix whatever's wrong with the SBS pack alignment that produced the
   "left half stretched + rainbow right half" symptom in Phase 2

**Cost**: Days. Mostly Hyprland monitor config, a small launcher script
extension, and probably some monado compositor config flags. No new
packages.

**Risk**: Medium. Each step is well-trodden in isolation; the
combination on Hyprland-on-Intel-Arc might surface its own gotchas.
The Phase 2 visual symptom suggests at least one geometry bug we
haven't characterized.

**Unblocks**: A working AR glasses experience using the open-source
stack, even if architecturally less clean than direct mode. Doesn't
require any upstream changes.

**Right choice if**: Jorge wants something visually working soon and
is OK with the lower-fidelity path. Probably the most pragmatic choice.

**Stop-the-loop pre-commitment**: 3 distinct attempts at SBS geometry
(documented separately) without a recognizable rendered scene = halt
and revisit whether monado-Wayland-windowed is even the right surface
type for this.

### Option C — Switch to a different OpenXR runtime

**What**: Replace Monado with an OpenXR runtime that doesn't depend on
Mesa's Vulkan WSI display extensions. Candidates would be runtimes
that use GBM/KMS directly, or that draw to a Wayland surface like
option B but with better SBS support out of the box.

**Cost**: Days to investigate, then unknown. Monado is the dominant
OSS OpenXR runtime; alternatives are scarce.

**Risk**: Very high. Most OSS Linux OpenXR work routes through Monado.
Likely no real alternative exists. Even if one does, it probably
hits the same Mesa gap — `VK_KHR_display` is the standard path.

**Unblocks**: Probably nothing — most paths converge on the same wall.

**Right choice if**: Investigation reveals a runtime that genuinely
bypasses the Mesa gap. Otherwise this is a dead branch.

**Stop-the-loop pre-commitment**: If 1 day of investigation finds no
runtime that demonstrably uses a different surface path on Intel,
halt this option.

### Option D — Different GPU (out of scope for `lewis`)

**What**: Use a host with NVIDIA or AMD GPU where the Vulkan display
extensions are implemented.

**Cost**: Hardware swap. N/A for `lewis`.

**Risk**: N/A.

**Unblocks**: The same XR stack would just work (modulo per-host EDID
override module).

**Right choice if**: Jorge has another box (`ace` has NVIDIA — but
runs GNOME/X11, different stack assumptions).

**Stop-the-loop pre-commitment**: N/A — out of scope.

## Recommendation

**Option B (Wayland-windowed + SBS)** is the highest expected value
per hour of effort. It's the only option that gives a probable visible
result without depending on either upstream investment (A) or finding
a unicorn runtime (C). The downside is architectural — direct mode
would have been cleaner — but architectural cleanness without visible
output is worth nothing.

The EDID override + USB ACL fix from Phase 3 stay in place either way:
they're useful infrastructure even when monado isn't using direct mode.

If Jorge wants to *invest*, A is the right answer (and benefits the
community). But that's a different kind of project than "get this
working today."

## What "shelve" looks like

If Jorge decides this isn't worth more time right now: close task #17
without action, leave the decision doc and Mesa-gap memory entry as
the breadcrumb for a future session. The Phase 3 architecture stays
deployed — when Mesa anv ever gains display plane support, breezy-hyprland
should just start working with no further code changes.

## What "do it" looks like (for whichever option)

Before any new code:

1. Re-read `memory/xr-mesa-anv-display-gap.md` to confirm the wall
   hasn't already moved (rerun the `vkcube --wsi display` reproduction).
2. Re-read `memory/xr-loop-history.md` to make sure the new attempt
   isn't a structural repeat of past dead ends.
3. Write a Phase 3.5 implementation plan as `xr/plans/05-...md` for
   the chosen option, with explicit halt conditions matching the
   stop-the-loop pre-commitments above.
4. Then start.

## References

- Architectural complete state: `xr/STATE.md` (lewis row)
- Original Phase 3 plan: `plans/03-hyprland-breezy-2026-05-06.md`
- The wall: `memory/xr-mesa-anv-display-gap.md`
- Past loops: `memory/xr-loop-history.md`
- Hardware constraints: `memory/xr-rayneo-hardware.md`
- Why Wayland-windowed Phase 2 looked rainbow: `xr/LEARNINGS.md`
