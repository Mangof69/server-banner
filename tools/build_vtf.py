#!/usr/bin/env python3
"""Build a Source-compatible VTF 7.2 full-screen overlay texture.

The source artwork keeps its aspect ratio and is placed on a transparent
1024x1024 canvas. env_screenoverlay maps that canvas over the whole viewport,
so transparency is required for a narrow banner rather than an opaque stripe.
"""
import struct
import sys
from pathlib import Path
from PIL import Image

CANVAS_SIZE = 1024
MAX_BANNER_HEIGHT = 180
TOP_MARGIN = 28
HEADER_SIZE = 80

# CLAMPS | CLAMPT | NOMIP | NOLOD | SRGB | EIGHTBITALPHA.
# 0x2000 is EIGHTBITALPHA only (not ONEBITALPHA).
TEXTURE_FLAGS = 0x0000234C
IMAGE_FORMAT_RGBA8888 = 0
IMAGE_FORMAT_NONE = -1

if len(sys.argv) != 3:
    raise SystemExit("usage: build_vtf.py input-image output.vtf")

src = Path(sys.argv[1])
dst = Path(sys.argv[2])

with Image.open(src) as source:
    artwork = source.convert("RGBA")
    scale = min(
        CANVAS_SIZE / artwork.width,
        MAX_BANNER_HEIGHT / artwork.height,
    )
    out_width = max(1, int(round(artwork.width * scale)))
    out_height = max(1, int(round(artwork.height * scale)))
    artwork = artwork.resize((out_width, out_height), Image.Resampling.LANCZOS)

canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
x = (CANVAS_SIZE - out_width) // 2
y = TOP_MARGIN
if y + out_height > CANVAS_SIZE:
    raise SystemExit("banner placement exceeds canvas")
canvas.alpha_composite(artwork, (x, y))
pixels = canvas.tobytes()

header = bytearray(HEADER_SIZE)
header[0:4] = b"VTF\x00"
struct.pack_into("<II", header, 4, 7, 2)
struct.pack_into("<I", header, 12, HEADER_SIZE)
struct.pack_into("<HH", header, 16, CANVAS_SIZE, CANVAS_SIZE)
struct.pack_into("<I", header, 20, TEXTURE_FLAGS)
struct.pack_into("<HH", header, 24, 1, 0)  # one frame, first frame 0
# VTF 7.2 reflectivity padding and alignment are zero-initialized.
struct.pack_into("<fff", header, 32, 0.0, 0.0, 0.0)
struct.pack_into("<f", header, 48, 1.0)
struct.pack_into("<I", header, 52, IMAGE_FORMAT_RGBA8888)
header[56] = 1  # one mip level
struct.pack_into("<i", header, 57, IMAGE_FORMAT_NONE)  # no low-res thumbnail
header[61] = 0
header[62] = 0
struct.pack_into("<H", header, 63, 1)  # 2D texture depth

dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_bytes(header + pixels)

# Read-back validation: verify the complete 7.2 header and pixel payload.
data = dst.read_bytes()
if data[:4] != b"VTF\x00":
    raise SystemExit("VTF signature validation failed")
major, minor = struct.unpack_from("<II", data, 4)
header_size = struct.unpack_from("<I", data, 12)[0]
width, height = struct.unpack_from("<HH", data, 16)
flags = struct.unpack_from("<I", data, 20)[0]
frames, first_frame = struct.unpack_from("<HH", data, 24)
image_format = struct.unpack_from("<I", data, 52)[0]
mip_count = data[56]
lowres_format = struct.unpack_from("<i", data, 57)[0]
lowres_width, lowres_height = data[61], data[62]
depth = struct.unpack_from("<H", data, 63)[0]
expected_size = HEADER_SIZE + CANVAS_SIZE * CANVAS_SIZE * 4

expected = (
    7, 2, HEADER_SIZE, CANVAS_SIZE, CANVAS_SIZE, TEXTURE_FLAGS,
    1, 0, IMAGE_FORMAT_RGBA8888, 1, IMAGE_FORMAT_NONE, 0, 0, 1,
    expected_size,
)
actual = (
    major, minor, header_size, width, height, flags, frames, first_frame,
    image_format, mip_count, lowres_format, lowres_width, lowres_height,
    depth, len(data),
)
if actual != expected:
    raise SystemExit(f"VTF header or payload validation failed: {actual!r}")

alpha = canvas.getchannel("A")
alpha_bbox = alpha.getbbox()
if alpha_bbox is None:
    raise SystemExit("banner input produced a fully transparent VTF")
print(
    f"Validated {dst}: VTF {major}.{minor}, {width}x{height}, RGBA8888, "
    f"flags=0x{flags:08X}, artwork={out_width}x{out_height}, "
    f"alpha_bounds={alpha_bbox}, bytes={len(data)}"
)
