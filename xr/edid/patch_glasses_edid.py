#!/usr/bin/env python3
"""
Patch the Rayneo Air 4 Pro EDID for direct-mode VR on Linux.

Two modifications:

1. Insert a Microsoft HMD Vendor-Specific Data Block (VSDB) into the
   CTA-861 extension so the kernel sets `connector.non_desktop = true`.
   wlroots/Hyprland then advertise the connector via `wp-drm-lease-v1`
   so monado can take a direct DRM lease.

   Layout (see learn.microsoft.com/.../specialized-monitors-edid-extension):
     byte  0: tag/length = (3<<5)|21 = 0x75   (vendor tag, 21-byte payload)
     bytes 1-3: OUI = 0x5C 0x12 0xCA  (Microsoft IEEE OUI = 0xCA125C, LSB-first)
     byte  4: version = 0x02   (HMD for non-Microsoft compositors)
     byte  5: flags+use_case = 0x00 (per spec, must be 0 for v0x1/v0x2)
     bytes 6-21: container ID (16 bytes; zero — Linux ignores it)

2. Add a 3840x1080@60 DTD so monado renders SBS at the panel's native
   per-eye resolution (1920x1080 per eye = 3840x1080 packed). Without
   this the kernel only exposes the EDID's 1920x1080 modes, monado
   clamps its 3840 surface to 1920, and the rendered SBS image lands
   wrongly (left half black, right half rainbow streaks). With this
   mode added, monado's `choose_best_vk_mode_auto` picks 3840x1080
   (most pixels) and renders correctly.

   The new DTD is inserted at the START of the base EDID's DTD list
   (replacing the original DTD 1) so it becomes the "first detailed
   timing" — the kernel-preferred mode. The two original 1920x1080
   modes remain available as DTD 2 (base) and DTD 3 (CTA).

Run from the repo root:
  python3 xr/edid/patch_glasses_edid.py \
      xr/edid/glasses-original.bin xr/edid/glasses-nondesktop.bin
"""

from __future__ import annotations

import sys
from pathlib import Path

MICROSOFT_VSDB = bytes([
    0x75,                # tag=3 (vendor-specific), length=21
    0x5C, 0x12, 0xCA,    # Microsoft IEEE OUI, LSB-first
    0x02,                # VSDB version: HMD for non-Microsoft compositors
    0x00,                # flags + use case (spec: zero for v0x1/v0x2)
    # 16-byte container ID — kernel doesn't care, leave zero.
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
])
assert len(MICROSOFT_VSDB) == 22, "VSDB must be 22 bytes (1 header + 21 payload)"


def make_dtd(
    pixel_clock_khz: int,
    h_active: int, h_blank: int, h_sync_off: int, h_sync_pulse: int,
    v_active: int, v_blank: int, v_sync_off: int, v_sync_pulse: int,
    h_image_mm: int, v_image_mm: int,
    hpol: bool = True, vpol: bool = True,
) -> bytes:
    """
    Encode an 18-byte VESA Detailed Timing Descriptor.

    See VESA EDID 1.4 spec, section 3.10.2 for byte-level layout.
    Values are encoded with low byte first and a packed high-nibble byte.
    """
    pclk_units = pixel_clock_khz // 10  # DTD pixel clock is in 10 kHz units
    if pclk_units > 0xFFFF:
        raise SystemExit(f"Pixel clock {pixel_clock_khz} kHz too high for DTD encoding")

    def split(val: int) -> tuple[int, int]:
        # (low 8 bits, high 4 bits)
        return val & 0xFF, (val >> 8) & 0x0F

    h_act_lo, h_act_hi = split(h_active)
    h_bl_lo, h_bl_hi = split(h_blank)
    v_act_lo, v_act_hi = split(v_active)
    v_bl_lo, v_bl_hi = split(v_blank)
    hso_lo, hso_hi = split(h_sync_off)
    hsp_lo, hsp_hi = split(h_sync_pulse)
    vso_lo, vso_hi = v_sync_off & 0x0F, (v_sync_off >> 4) & 0x03
    vsp_lo, vsp_hi = v_sync_pulse & 0x0F, (v_sync_pulse >> 4) & 0x03
    h_img_lo, h_img_hi = split(h_image_mm)
    v_img_lo, v_img_hi = split(v_image_mm)

    # Features byte: bit 4=1 (digital separate sync), bit 1=hpol, bit 2=vpol
    features = 0x18  # digital separate sync, both polarities default positive
    if hpol:
        features |= 0x02
    if vpol:
        features |= 0x04

    return bytes([
        pclk_units & 0xFF,                                      # 0
        (pclk_units >> 8) & 0xFF,                               # 1
        h_act_lo,                                               # 2
        h_bl_lo,                                                # 3
        (h_act_hi << 4) | h_bl_hi,                              # 4
        v_act_lo,                                               # 5
        v_bl_lo,                                                # 6
        (v_act_hi << 4) | v_bl_hi,                              # 7
        hso_lo,                                                 # 8
        hsp_lo,                                                 # 9
        (vso_lo << 4) | vsp_lo,                                 # 10
        (hso_hi << 6) | (hsp_hi << 4) | (vso_hi << 2) | vsp_hi, # 11
        h_img_lo,                                               # 12
        v_img_lo,                                               # 13
        (h_img_hi << 4) | v_img_hi,                             # 14
        0x00,                                                   # 15 (h border)
        0x00,                                                   # 16 (v border)
        features,                                               # 17
    ])


# 3840x1080 @ 60 Hz, derived by doubling H values of the original 1920x1080@60
# DTD (pclk 148.5 MHz, hfp 88, hsync 44, hback 148, vfp 4, vsync 5, vback 36).
# Doubling H gives total 4400x1125 → 297 MHz pixel clock. DP HBR2 (10.8 Gb/s
# at 270 MHz/lane * 4) easily covers 297 MHz * 24 bpp = 7.13 Gb/s.
NEW_DTD_3840x1080 = make_dtd(
    pixel_clock_khz=297000,
    h_active=3840, h_blank=560,
    h_sync_off=176, h_sync_pulse=88,
    v_active=1080, v_blank=45,
    v_sync_off=4, v_sync_pulse=5,
    h_image_mm=200, v_image_mm=56,  # rough panel size
    hpol=True, vpol=True,
)
assert len(NEW_DTD_3840x1080) == 18, "DTD must be 18 bytes"


def patch(edid: bytes) -> bytes:
    if len(edid) < 256:
        raise SystemExit(f"EDID too short ({len(edid)} bytes); need at least 256")
    if edid[126] != 0x01:
        raise SystemExit(
            f"Base EDID claims {edid[126]} extension blocks; this patcher only handles 1"
        )

    # ----- Base EDID changes: replace DTD 1 (offset 0x36..0x47) with 3840x1080 -----
    base = bytearray(edid[:128])
    # DTD slot 1 spans bytes 0x36..0x47 (18 bytes).
    base[0x36:0x36 + 18] = NEW_DTD_3840x1080

    # Bump the Display Range Limits descriptor's max pixel clock to 300 MHz so
    # the kernel accepts our 297 MHz 3840x1080 mode. Some kernels validate
    # added modes against this cap (drivers/gpu/drm/drm_edid.c
    # mode_in_range / drm_mode_validate_size). The original is 160 MHz which
    # would reject 297 MHz outright on strict kernels.
    #
    # Display Range Limits descriptor lives in slot 3 of base EDID, bytes
    # 0x5a..0x6b. Format (VESA EDID 1.4 §3.10.3.3.1):
    #   0x5a..0x5d : 00 00 00 fd  (descriptor header)
    #   0x5e       : flags / range offsets
    #   0x5f       : min vertical rate (Hz)
    #   0x60       : max vertical rate (Hz)
    #   0x61       : min horizontal rate (kHz)
    #   0x62       : max horizontal rate (kHz)
    #   0x63       : max pixel clock / 10 MHz   ← bump this
    #   0x64       : timing descriptor type tag (0x00 = GTF default)
    #   0x65..0x6b : padding (0x0a then spaces)
    if base[0x5a:0x5e] == bytes([0x00, 0x00, 0x00, 0xfd]):
        base[0x63] = 30  # 30 * 10 MHz = 300 MHz cap
    # else: descriptor moved or not present — skip silently to keep the patch
    # robust if the source EDID layout changes.

    # Recompute base EDID checksum (byte 127): sum of bytes 0..126 plus checksum
    # must be 0 mod 256.
    base[127] = (-sum(base[:127])) & 0xFF
    assert sum(base) % 256 == 0, "base EDID checksum recomputation failed"

    # ----- CTA-861 extension changes: insert Microsoft HMD VSDB at end of DBC -----
    cta = bytearray(edid[128:256])
    if cta[0] != 0x02:
        raise SystemExit(f"Extension block at offset 128 is type 0x{cta[0]:02x}, not CTA-861")

    revision = cta[1]
    dtd_offset = cta[2]
    flags = cta[3]
    if dtd_offset < 4 or dtd_offset > 127:
        raise SystemExit(f"Bogus DTD offset {dtd_offset}")

    # Anatomy: header (4) + data block collection (dtd_offset-4 bytes) +
    # DTDs + 18-byte padding + checksum.
    data_blocks = bytes(cta[4:dtd_offset])
    after_dbc = bytes(cta[dtd_offset:127])

    new_data_blocks = data_blocks + MICROSOFT_VSDB
    new_dtd_offset = 4 + len(new_data_blocks)
    if new_dtd_offset > 127:
        raise SystemExit(
            f"Inserting VSDB pushes DTD offset to {new_dtd_offset}, no room"
        )

    bytes_consumed_from_padding = len(MICROSOFT_VSDB)
    trimmed_after = after_dbc[: len(after_dbc) - bytes_consumed_from_padding]

    # Verify we only ate padding (zeros), not real DTD bytes.
    eaten = after_dbc[len(after_dbc) - bytes_consumed_from_padding:]
    if any(b != 0x00 for b in eaten):
        raise SystemExit(
            "Refusing to overwrite non-zero bytes at end of CTA-861 block; "
            "would clobber a DTD. Use a smaller VSDB or hand-edit."
        )

    new_cta = bytearray()
    new_cta.append(0x02)               # tag
    new_cta.append(revision)
    new_cta.append(new_dtd_offset)
    new_cta.append(flags)
    new_cta.extend(new_data_blocks)
    new_cta.extend(trimmed_after)
    assert len(new_cta) == 127, f"pre-checksum CTA len {len(new_cta)} != 127"
    checksum = (-sum(new_cta)) & 0xFF
    new_cta.append(checksum)
    assert sum(new_cta) % 256 == 0, "checksum recomputation failed"

    return bytes(base) + bytes(new_cta)


def main() -> None:
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    out = patch(src.read_bytes())
    dst.write_bytes(out)
    print(f"wrote {dst} ({len(out)} bytes)")


if __name__ == "__main__":
    main()
