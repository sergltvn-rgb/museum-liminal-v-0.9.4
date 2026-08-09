"""Build native-resolution review sheets from decor audit view frames.

No resizing: every frame is pasted at its captured 640x268 size, so geometry
and placement judgements are made on native pixels. Grid order is printed so
the reviewer knows which cell is which shot.
"""
import os
import sys
from PIL import Image

VIEW = os.path.join("shots", "decor_audit", "after", "view")
OUT = os.path.join("shots", "decor_audit", "review_2026-08-06")

GROUPS = {
    "planetarium": (1, [
        "overview_planetarium",
        "planetarium_dome",
        "planetarium_projector",
        "planetarium_seating",
        "planetarium_booth",
    ]),
    "atrium": (2, [
        "overview_atrium_south",
        "overview_atrium_west",
        "atrium_core",
        "atrium_signage",
        "atrium_barrier",
        "atrium_cables",
        "atrium_reception",
        "atrium_directory",
    ]),
    "office": (2, [
        "overview_office",
        "office_monitors",
        "office_computer",
        "import_pc_monitors",
        "office_desk",
        "office_chair",
    ]),
    "cabinets": (2, [
        "office_key_cabinet",
        "storage_hazard",
        "storage_hide_locker",
        "office_hide_locker",
        "import_bookcases",
        "storage_shelves_west",
    ]),
}


def build(name, cols, names, source=VIEW, out_dir=OUT):
    frames = []
    for shot in names:
        path = os.path.join(source, shot + ".jpg")
        if not os.path.exists(path):
            print("MISSING %s" % path)
            continue
        frames.append((shot, Image.open(path).convert("RGB")))
    if not frames:
        print("EMPTY %s" % name)
        return
    cell_w = max(img.width for _, img in frames)
    cell_h = max(img.height for _, img in frames)
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w, rows * cell_h), (10, 10, 12))
    order = []
    for index, (shot, img) in enumerate(frames):
        row, col = divmod(index, cols)
        sheet.paste(img, (col * cell_w, row * cell_h))
        order.append("r%dc%d=%s" % (row + 1, col + 1, shot))
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + ".jpg")
    sheet.save(path, quality=90)
    print("%s %dx%d %d bytes | %s" % (
        path, sheet.size[0], sheet.size[1], os.path.getsize(path),
        " ".join(order)))


def main():
    if len(sys.argv) > 1:
        wanted = set(sys.argv[1:])
    else:
        wanted = set(GROUPS)
    for name, (cols, names) in GROUPS.items():
        if name in wanted:
            build(name, cols, names)


if __name__ == "__main__":
    main()
