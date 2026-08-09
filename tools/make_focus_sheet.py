"""Collect native-resolution decor capture frames into one contact sheet.

Usage:
    python tools/make_focus_sheet.py <view_dir> <out.jpg> <cols> <name> [name...]

Frames are pasted at their native size (640x268) with no resampling: every
decision about geometry and placement has to be made on real pixels. Each cell
gets a small caption strip above it so the frame pixels themselves stay clean.
"""

import os
import sys

from PIL import Image, ImageDraw


def main() -> int:
    if len(sys.argv) < 5:
        print(__doc__)
        return 2
    view_dir = sys.argv[1]
    out_path = sys.argv[2]
    cols = int(sys.argv[3])
    names = sys.argv[4:]

    tiles = []
    for name in names:
        path = os.path.join(view_dir, name + ".jpg")
        if not os.path.exists(path):
            print("MISSING %s" % path)
            return 1
        tiles.append((name, Image.open(path).convert("RGB")))

    cell_w = max(im.width for _, im in tiles)
    cell_h = max(im.height for _, im in tiles)
    header = 14
    rows = (len(tiles) + cols - 1) // cols

    sheet = Image.new("RGB", (cols * cell_w, rows * (cell_h + header)), (18, 18, 18))
    draw = ImageDraw.Draw(sheet)
    for index, (name, im) in enumerate(tiles):
        row, col = divmod(index, cols)
        x = col * cell_w
        y = row * (cell_h + header)
        draw.text((x + 4, y + 2), name, fill=(255, 226, 120))
        sheet.paste(im, (x, y + header))

    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    sheet.save(out_path, quality=92)
    print("wrote %s %dx%d from %d frames" % (out_path, sheet.width, sheet.height, len(tiles)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
