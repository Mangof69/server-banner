#!/usr/bin/env python3
"""Create a VTF 7.2 RGBA8888 texture from the repository's banner.jpg."""
import struct
import sys
from pathlib import Path
from PIL import Image

if len(sys.argv) != 3:
    raise SystemExit("usage: build_vtf.py input.jpg output.vtf")

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
image = Image.open(src).convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
pixels = image.tobytes()

# VTF 7.2, 80-byte header, one frame, one mip level, RGBA8888 (format 0).
header = bytearray(80)
header[0:4] = b"VTF\x00"
struct.pack_into("<II", header, 4, 7, 2)
struct.pack_into("<I", header, 12, 80)
struct.pack_into("<HH", header, 16, 1024, 1024)
struct.pack_into("<I", header, 20, 0x230C)  # clamp S/T, no mipmaps, no LOD
struct.pack_into("<HH", header, 24, 1, 0)    # frames, first frame
struct.pack_into("<fff", header, 32, 0.0, 0.0, 0.0)  # reflectivity
struct.pack_into("<f", header, 48, 1.0)      # bump map scale
struct.pack_into("<I", header, 52, 0)        # IMAGE_FORMAT_RGBA8888
header[56] = 1                               # mip count
struct.pack_into("<i", header, 57, -1)       # no low-res image
header[61] = 0
header[62] = 0
struct.pack_into("<H", header, 63, 1)        # depth

dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_bytes(header + pixels)
if dst.stat().st_size != 80 + 1024 * 1024 * 4:
    raise SystemExit("VTF size validation failed")
print(f"Created {dst} ({dst.stat().st_size} bytes), VTF 7.2 RGBA8888 1024x1024")
