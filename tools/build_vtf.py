#!/usr/bin/env python3
"""Build a Source-compatible full-screen banner overlay VTF.

env_screenoverlay maps the material over the whole viewport. CSS clients commonly
use 16:9; the VTF uses a 2:1 power-of-two canvas and the artwork is pre-scaled
horizontally to compensate for the 16:9 viewport stretch. All pixels outside
the banner remain transparent.
"""
import struct
import sys
from pathlib import Path
from PIL import Image

CANVAS_WIDTH = 1024
CANVAS_HEIGHT = 512
MAX_BANNER_HEIGHT = 120
TOP_MARGIN = 16
TARGET_SCREEN_ASPECT = 16.0 / 9.0
HEADER_SIZE = 80

# CLAMPS | CLAMPT | SRGB | NOMIP | NOLOD | EIGHTBITALPHA.
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
    original_aspect = artwork.width / artwork.height

    # A power-of-two 1024x512 texture is 2:1. env_screenoverlay stretches it
    # to the player's viewport. Compensate for the standard 16:9 viewport so
    # the artwork itself keeps its original aspect ratio in-game.
    canvas_aspect = CANVAS_WIDTH / CANVAS_HEIGHT
    horizontal_compensation = canvas_aspect / TARGET_SCREEN_ASPECT

    out_height = min(MAX_BANNER_HEIGHT, CANVAS_HEIGHT - TOP_MARGIN)
    out_width = int(round(out_height * original_aspect * horizontal_compensation))

    # Keep a safety margin on both sides if an unusually wide source is used.
    max_width = CANVAS_WIDTH - 64
    if out_width > max_width:
        factor = max_width / out_width
        out_width = max_width
        out_height = max(1, int(round(out_height * factor)))

    artwork = artwork.resize((out_width, out_height), Image.Resampling.LANCZOS)

canvas = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 0))
x = (CANVAS_WIDTH - out_width) // 2
y = TOP_MARGIN
if y + out_height > CANVAS_HEIGHT:
    raise SystemExit("banner placement exceeds canvas")
canvas.alpha_composite(artwork, (x, y))
pixels = canvas.tobytes()

header = bytearray(HEADER_SIZE)
header[0:4] = b"VTF\x00"
struct.pack_into("<II", header, 4, 7, 2)
struct.pack_into("<I", header, 12, HEADER_SIZE)
struct.pack_into("<HH", header, 16, CANVAS_WIDTH, CANVAS_HEIGHT)
struct.pack_into("<I", header, 20, TEXTURE_FLAGS)
struct.pack_into("<HH", header, 24, 1, 0)  # one frame, first frame 0
struct.pack_into("<fff", header, 32, 0.0, 0.0, 0.0)  # reflectivity
struct.pack_into("<f", header, 48, 1.0)  # bumpmap scale
struct.pack_into("<I", header, 52, IMAGE_FORMAT_RGBA8888)
header[56] = 1  # one mip level
struct.pack_into("<i", header, 57, IMAGE_FORMAT_NONE)  # no low-res thumbnail
header[61] = 0
header[62] = 0
struct.pack_into("<H", header, 63, 1)  # 2D texture depth

dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_bytes(header + pixels)

# Read-back validation: verify the VTF 7.2 header and exact image payload.
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
expected_size = HEADER_SIZE + CANVAS_WIDTH * CANVAS_HEIGHT * 4

expected = (
    7, 2, HEADER_SIZE, CANVAS_WIDTH, CANVAS_HEIGHT, TEXTURE_FLAGS,
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

alpha_bbox = canvas.getchannel("A").getbbox()
if alpha_bbox is None:
    raise SystemExit("banner input produced a fully transparent VTF")
print(
    f"Validated {dst}: VTF {major}.{minor}, {width}x{height}, RGBA8888, "
    f"flags=0x{flags:08X}, artwork={out_width}x{out_height}, "
    f"alpha_bounds={alpha_bbox}, bytes={len(data)}"
)
