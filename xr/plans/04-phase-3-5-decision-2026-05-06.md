# Phase 3.5 — Decision: how (or whether) to push past the Mesa anv wall

Started: 2026-05-06
Status: Awaiting Jorge's pick

## Where we are

Phase 3 is architecturally complete: EDID override flips
`non_desktop=1`, wlroots advertises the connector via
`wp-drm-lease-v1`, monado takes the lease, OpenXR session reaches
FOCUSED with the real Rayneo head device. **Glasses are still black**:
the first `vkQueuePresentKHR` after surface creation fails with
`VK_ERROR_SURFACE_LOST_KHR`.

Reproduced independently of monado: `vkcube --wsi display` fails the
same way. Mesa's `anv` driver advertises `VK_KHR_display` at the
instance level but doesn't implement the device-level functions on
Intel Arc. Diagnosis + reproduction recipe:
`memory/xr-mesa-anv-display-gap.md`.

## The four options

### A — Patch Mesa anv

Implement the missing `VK_KHR_display` device functions in `anv`.
Submit upstream or carry as a local overlay.

- **Cost**: weeks minimum, plausibly months with review cycles
- **Risk**: high — there may be deeper anv blockers we hit only after
  starting
- **Payoff**: solves direct-mode VR on Intel Arc for everyone, not
  just us
- **Pick if**: investing in the Linux VR ecosystem is itself a goal

### B — Wayland-windowed mode + solve the SBS rendering

Drop the direct-mode path; let monado fall back to Wayland-windowed
(Phase 2 baseline). Then: toggle the glasses into 3D SBS mode via the
rayneo HID driver, advertise a 3840x1080 mode on the connector,
fullscreen monado's window onto the glasses output, fix the SBS pack
geometry that produced "left half stretched + rainbow right half" in
Phase 2.

- **Cost**: days
- **Risk**: medium — each step is well-trodden separately; the
  combination on Hyprland-on-Intel-Arc may have its own gotchas
- **Payoff**: probable visual output. Architecturally less clean than
  direct mode.
- **Pick if**: visible result soon matters more than architectural
  purity

### C — Different OpenXR runtime

Replace Monado with a runtime that draws via GBM/KMS or a different
WSI path that bypasses the Mesa display extensions.

- **Cost**: a day to investigate viability, then unknown
- **Risk**: very high — Monado is the only mature OSS Linux OpenXR
  runtime; alternatives are likely to either not exist or hit the
  same wall
- **Payoff**: only matters if a real alternative exists
- **Pick if**: investigation surfaces a credible candidate. Otherwise
  dead branch.

### D — Different GPU

N/A for `lewis`. Noted only for completeness — `ace` has NVIDIA but
runs GNOME/X11 with a different stack.

## Recommendation

**B if you want it working. A if you want to invest. C and D not
seriously on the table.**

The EDID override + USB ACL fix from Phase 3 stay deployed either
way — they're useful infrastructure regardless of which path forward.

If neither A nor B feels worth the effort: shelve. The Phase 3
architecture is preserved; whenever Mesa anv eventually gains display
plane support, `breezy-hyprland` will just start working with no
further code changes.

## References

- Diagnosis of the wall: `memory/xr-mesa-anv-display-gap.md`
- Architectural state: `xr/STATE.md` (lewis row)
- Original Phase 3 plan: `plans/03-hyprland-breezy-2026-05-06.md`
- Why Phase 2 looked rainbow: `xr/LEARNINGS.md`
