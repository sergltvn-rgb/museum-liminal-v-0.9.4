"""Print mean RGB over a coarse grid of a capture frame, plus optional rects.

A prop that "looks pale" is an impression; a mean RGB is evidence. This reads
native 640x268 view frames (no resampling anywhere in the chain) so the numbers
describe the pixels Godot actually rendered.

Usage:
  python tools/lowpoly/probe_pixels.py <frame.jpg> [cols rows]
  python tools/lowpoly/probe_pixels.py <frame.jpg> rect x y w h [x y w h ...]
"""

import sys

from PIL import Image


def mean_rgb(image, box):
    crop = image.crop(box)
    pixels = list(crop.getdata())
    if not pixels:
        return (0, 0, 0)
    count = len(pixels)
    return tuple(round(sum(p[i] for p in pixels) / count) for i in range(3))


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    image = Image.open(path).convert("RGB")
    print("%s %dx%d" % (path, image.width, image.height))

    if len(sys.argv) > 2 and sys.argv[2] == "rect":
        values = [int(v) for v in sys.argv[3:]]
        for i in range(0, len(values), 4):
            x, y, w, h = values[i:i + 4]
            print("  rect %4d,%4d %3dx%-3d mean=%s" % (
                x, y, w, h, mean_rgb(image, (x, y, x + w, y + h))))
        return 0

    cols = int(sys.argv[2]) if len(sys.argv) > 2 else 16
    rows = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    cell_w = image.width // cols
    cell_h = image.height // rows
    header = "      " + "".join("%-12d" % c for c in range(cols))
    print(header)
    for r in range(rows):
        line = "r%-4d" % r
        for c in range(cols):
            box = (c * cell_w, r * cell_h, (c + 1) * cell_w, (r + 1) * cell_h)
            red, green, blue = mean_rgb(image, box)
            line += " %3d,%3d,%3d" % (red, green, blue)
        print(line)
    print("cell %dx%d px" % (cell_w, cell_h))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
