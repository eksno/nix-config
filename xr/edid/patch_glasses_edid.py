#!/usr/bin/env python3
"""
Patch the Rayneo Air 4 Pro EDID to set the non_desktop bit.

The Linux DRM subsystem sets `connector.non_desktop = true` when it detects
a Microsoft HMD Vendor-Specific Data Block (VSDB) in the CTA-861 extension
block. The kernel function `cea_db_is_microsoft_vsdb` recognizes:
  - vendor-specific tag (3)
  - payload length 21 bytes (3 OUI + 18 vendor data)
  - OUI bytes 0x5C 0x12 0xCA (Microsoft IEEE OUI = 0xCA125C, LSB-first)

Once this bit is set, wlroots/Hyprland advertise the connector via
`wp-drm-lease-v1` so monado can take a direct DRM lease.

VSDB layout we write (see learn.microsoft.com/.../specialized-monitors-edid-extension):
  byte  0: tag/length = (3<<5)|21 = 0x75   (vendor tag, 21-byte payload)
  bytes 1-3: OUI = 0x5C 0x12 0xCA
  byte  4: version = 0x02   (HMD for non-Microsoft compositors)
  byte  5: flags+use_case = 0x00 (per spec, must be 0 for v0x1/v0x2)
  bytes 6-21: container ID (16 bytes; zero — Linux ignores it)

Strategy: insert this 22-byte block at the END of the existing data block
collection in the CTA-861 extension, shift the DTDs forward by 22 bytes
(there's 86 bytes of padding so plenty of room), bump the DTD start offset
(byte 2 of the extension), and recompute the extension's checksum.

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


def patch(edid: bytes) -> bytes:
    if len(edid) < 256:
        raise SystemExit(f"EDID too short ({len(edid)} bytes); need at least 256")
    if edid[126] != 0x01:
        raise SystemExit(
            f"Base EDID claims {edid[126]} extension blocks; this patcher only handles 1"
        )

    # The CTA-861 block starts at byte 128 of the linear EDID; its block-relative
    # offsets are what the kernel reads. Use a separate buffer to make this clear.
    base = bytearray(edid[:128])
    cta = bytearray(edid[128:256])

    if cta[0] != 0x02:
        raise SystemExit(f"Extension block at offset 128 is type 0x{cta[0]:02x}, not CTA-861")

    revision = cta[1]
    dtd_offset = cta[2]
    flags = cta[3]
    if dtd_offset < 4 or dtd_offset > 127:
        raise SystemExit(f"Bogus DTD offset {dtd_offset}")

    # Anatomy of the existing block: header (4) + data block collection
    # (dtd_offset-4 bytes) + DTDs + 18-byte padding + checksum.
    data_blocks = bytes(cta[4:dtd_offset])
    after_dbc = bytes(cta[dtd_offset:127])  # DTDs + padding (excludes checksum)

    new_data_blocks = data_blocks + MICROSOFT_VSDB
    new_dtd_offset = 4 + len(new_data_blocks)
    if new_dtd_offset > 127:
        raise SystemExit(
            f"Inserting VSDB pushes DTD offset to {new_dtd_offset}, no room"
        )

    # Trailing region (DTDs + padding) shifts forward by 22 bytes — we trim
    # the equivalent number of padding bytes from the END to keep the block
    # at exactly 128 bytes. CTA-861 spec requires unused space to be 0x00.
    bytes_consumed_from_padding = len(MICROSOFT_VSDB)
    trimmed_after = after_dbc[: len(after_dbc) - bytes_consumed_from_padding]

    # Verify we only ate padding (zeros), not real DTD bytes.
    eaten = after_dbc[len(after_dbc) - bytes_consumed_from_padding :]
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
    # Checksum: sum of all 128 bytes mod 256 must be 0.
    checksum = (-sum(new_cta)) & 0xFF
    new_cta.append(checksum)
    assert sum(new_cta) % 256 == 0, "checksum recomputation failed"

    # Base EDID is unchanged; its own checksum (byte 127) is unaffected by
    # extension content. Sanity-check we didn't break it.
    if sum(base) % 256 != 0:
        raise SystemExit("Base EDID checksum already invalid in input — bailing")

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
