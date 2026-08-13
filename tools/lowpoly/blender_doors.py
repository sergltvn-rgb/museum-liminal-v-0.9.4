"""Two authored 0.86 m museum door leaves.

lp_service_door_leaf is pressed steel for staff/archive/restoration openings.
lp_gallery_door_leaf repeats the glazed/brass language of the public entrance
at the narrower 1.80 m interior doorway. Both use a hinge-axis origin.
"""
from __future__ import annotations

import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import blender_build as bb  # noqa: E402

OUT_DIR = bb.OUT_DIR
REPORT_PATH = os.path.join(bb.REPO_ROOT, "street_master_review", "door_modules.json")
W = 0.86
Y0 = 0.05
Y1 = 2.47
T = 0.055


def build_service(material):
    p = bb.Part("lp_service_door_leaf")
    # Folded steel perimeter with three pressed fields. Nothing uses a wood swatch.
    p.box((W * 0.5, (Y0 + Y1) * 0.5, 0.0), (W, Y1 - Y0, T), "door_dark",
          face_swatches={"px": "carcass_dark", "nx": "carcass_dark",
                         "py": "handle_dark", "ny": "handle_dark"})
    for cy, h in ((1.96, 0.64), (1.22, 0.56), (0.55, 0.45)):
        for axis, z in (("pz", T * 0.5 + 0.0015),
                        ("nz", -T * 0.5 - 0.0015)):
            p.panel((W * 0.5, cy, z), (0.58, h), "door", axis)
            p.panel((W * 0.5, cy, z + (0.001 if axis == "pz" else -0.001)),
                    (0.47, h - 0.11), "door_dark", axis)
    for hy in (0.34, 1.28, 2.22):
        p.prism((0.0, hy, 0.0), 0.024, 0.10, 6, "hinge",
                cap_swatch="handle_dark")
    for side in (-1, 1):
        face = side * (T * 0.5)
        axis = "pz" if side > 0 else "nz"
        p.box((W - 0.10, 1.04, face + side * 0.010),
              (0.09, 0.09, 0.018), "handle_dark")
        p.box((W - 0.18, 1.04, face + side * 0.030),
              (0.16, 0.032, 0.030), "handle")
        p.panel((W * 0.5, 0.22, face + side * 0.002),
                (0.60, 0.25), "handle_dark", axis)
    p.panel((W * 0.50, 1.67, T * 0.5 + 0.003), (0.20, 0.07), "label", "pz")
    return p, p.finish(material)


def build_gallery(material):
    p = bb.Part("lp_gallery_door_leaf")
    # Narrow ceremonial leaf: dark metal frame, tall dead-glass light and brass.
    stile = 0.115
    for cx in (stile * 0.5, W - stile * 0.5):
        p.box((cx, (Y0 + Y1) * 0.5, 0.0), (stile, Y1 - Y0, T),
              "carcass_dark", face_swatches={"px": "handle_dark", "nx": "handle_dark"})
    for cy, h in ((Y0 + 0.13, 0.26), (1.02, 0.13), (Y1 - 0.10, 0.20)):
        p.box((W * 0.5, cy, 0.0), (W - 2 * stile + 0.010, h, T),
              "carcass_dark", face_swatches={"py": "handle_dark", "ny": "handle_dark"})
    # Upper glass and lower recessed metal panel on both faces.
    p.box((W * 0.5, 1.73, 0.0), (0.59, 1.20, T - 0.020), "glass_dead",
          faces=("pz", "nz"), face_swatches={"pz": "glass_sheen", "nz": "glass_sheen"})
    p.box((W * 0.5, 0.60, 0.0), (0.59, 0.66, T - 0.018), "door_dark",
          faces=("pz", "nz"), face_swatches={"pz": "door", "nz": "door_dark"})
    for hy in (0.34, 1.28, 2.22):
        p.prism((0.0, hy, 0.0), 0.024, 0.10, 6, "hinge",
                cap_swatch="handle_dark")
    for side in (-1, 1):
        face = side * (T * 0.5)
        axis = "pz" if side > 0 else "nz"
        p.box((W - 0.095, 1.04, face + side * 0.012),
              (0.075, 0.24, 0.020), "lock")
        p.box((W - 0.175, 1.04, face + side * 0.032),
              (0.16, 0.032, 0.030), "handle")
        p.panel((W * 0.5, 0.21, face + side * 0.002),
                (0.58, 0.22), "lock", axis)
    return p, p.finish(material)


BUILDERS = (build_service, build_gallery)
BUDGET = {"lp_service_door_leaf": 500, "lp_gallery_door_leaf": 500}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
    material = bb.make_material()
    rows = []
    failures = []
    for builder in BUILDERS:
        part, obj = builder(material)
        path = os.path.join(OUT_DIR, part.name + ".glb")
        bb.export_glb(obj, path)
        lo, hi = part.bounds
        size = (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
        # The structural leaf runs exactly x 0..0.86. Hinge knuckles are
        # allowed to project 24 mm behind the pivot; no visible part may run
        # beyond the free edge into the jamb.
        if lo[0] < -0.025 or hi[0] > W + 0.001 or abs(lo[1] - Y0) > 1e-4:
            failures.append("%s hinge bounds %.4f..%.4f, y %.4f" %
                            (part.name, lo[0], hi[0], lo[1]))
        if abs(size[1] - (Y1 - Y0)) > 0.002:
            failures.append("%s height %s" % (part.name, size))
        if part.tris > BUDGET[part.name]:
            failures.append("%s tris %d" % (part.name, part.tris))
        rows.append({"module": part.name, "size": [round(v, 4) for v in size],
                     "triangles": part.tris, "bytes": os.path.getsize(path)})
        bpy.data.objects.remove(obj, do_unlink=True)
    with open(REPORT_PATH, "w", encoding="utf-8") as fh:
        json.dump(rows, fh, indent=2)
    for row in rows:
        print("MODEL", row["module"], row["size"], row["triangles"], "tris")
    if failures:
        for line in failures:
            print("FAIL", line)
        raise SystemExit("door build failed")
    print("BUILD_OK", len(rows), "models")


if __name__ == "__main__":
    main()
