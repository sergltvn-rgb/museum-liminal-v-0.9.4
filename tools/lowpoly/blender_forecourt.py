"""Authored Blender models for the museum forecourt.

Replaces the procedural ball-flowers, disconnected gate piers, tiered tube
fountain and plank benches.  All geometry is authored in Godot coordinates,
uses the shared 128 px palette atlas, flat shading and one material.

Run:
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b \
    --factory-startup --python tools/lowpoly/blender_forecourt.py
"""
from __future__ import annotations

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import blender_build as bb  # noqa: E402

OUT_DIR = bb.OUT_DIR
REPORT_PATH = os.path.join(bb.REPO_ROOT, "street_master_review",
                           "forecourt_modules.json")


def _flower(p, x, z, base_y, swatch, phase=0.0):
    """One readable flower: stem, two leaves, five separate petals, centre."""
    p.prism((x, base_y, z), 0.018, 0.24, 5, "leaf_dark")
    # Leaves are small blades, not another blob around the stem.
    p.box((x + 0.045, base_y + 0.11, z), (0.10, 0.025, 0.035), "leaf")
    p.box((x - 0.035, base_y + 0.16, z + 0.025),
          (0.075, 0.022, 0.030), "leaf_dark")
    head_y = base_y + 0.235
    for i in range(5):
        a = phase + math.tau * i / 5.0
        px = x + math.cos(a) * 0.060
        pz = z + math.sin(a) * 0.060
        p.prism((px, head_y, pz), 0.046, 0.028, 5, swatch,
                cap_swatch=swatch, phase=a)
    p.prism((x, head_y + 0.004, z), 0.034, 0.036, 6,
            "flower_cream", cap_swatch="flower_cream")


def _flower_bed(p, cx, cz, variant):
    p.prism((cx, 0.160, cz), 1.08, 0.13, 12, "court_stone_dark",
            cap_swatch="court_stone")
    p.prism((cx, 0.245, cz), 0.90, 0.065, 12, "court_soil",
            cap_swatch="court_soil")
    offsets = [(-0.48, -0.30), (-0.18, 0.38), (0.22, -0.46),
               (0.49, 0.20), (0.02, 0.02), (-0.55, 0.31), (0.46, -0.34)]
    colours = ("flower_red", "flower_cream", "flower_lilac")
    for i, (ox, oz) in enumerate(offsets):
        _flower(p, cx + ox, cz + oz, 0.300,
                colours[(i + variant) % len(colours)], 0.35 * (i + variant))


def build_garden(material):
    p = bb.Part("lp_forecourt_garden")
    # A complete half of the formal garden. Local -X is the open side facing
    # the central arrival walk; the same model is yawed 180 degrees in the west.
    base_mark = p.mark_faces()
    p.box((0.0, 0.070, 0.0), (12.80, 0.140, 13.80), "court_stone_dark",
          face_swatches={"py": "court_stone", "ny": "shadow"})
    p.bevel(p.facing(p.new_faces(base_mark), "py"), 0.035, "court_stone")
    p.box((0.0, 0.135, 0.0), (12.35, 0.090, 13.35), "court_grass",
          face_swatches={"ny": "shadow"})
    # Cross paths are inset into the lawn rather than floating on the same face.
    p.box((0.0, 0.177, 0.0), (12.00, 0.055, 1.42), "plinth")
    p.box((0.0, 0.178, 0.0), (1.42, 0.056, 12.95), "plinth")

    # Clipped boxwood: segmented, gently varied, and open on the inner side.
    for zi, z in enumerate((-4.95, -1.65, 1.65, 4.95)):
        h = 0.58 + (0.035 if zi in (1, 3) else 0.0)
        p.box((6.03, 0.180 + h * 0.5, z), (0.62, h, 3.18),
              "court_hedge", face_swatches={"py": "leaf_dark"})
    for zside in (-6.58, 6.58):
        for xi, x in enumerate((-4.62, -1.54, 1.54, 4.62)):
            h = 0.55 + (0.04 if xi in (0, 2) else 0.0)
            p.box((x, 0.180 + h * 0.5, zside), (2.96, h, 0.62),
                  "court_hedge", face_swatches={"py": "leaf_dark"})

    for variant, (x, z) in enumerate(((-3.0, -3.2), (-3.0, 3.2),
                                      (3.0, -3.2), (3.0, 3.2))):
        _flower_bed(p, x, z, variant)

    # Four restrained clipped yews anchor the corners; no cone floats above a tub.
    for x in (-4.75, 4.75):
        for z in (-4.88, 4.88):
            p.prism((x, 0.175, z), 0.44, 0.38, 10,
                    "court_stone_dark", cap_swatch="court_stone")
            p.prism((x, 0.525, z), 0.55, 1.38, 10, "court_hedge",
                    top_radius=0.075, cap_swatch="leaf_dark")
    return p, p.finish(material)


def build_fountain(material):
    p = bb.Part("lp_court_fountain")
    # Low reflecting basin: a quiet civic object, not the former wedding-cake
    # stack with 28 rigid vertical water tubes.
    p.prism((0.0, 0.0, 0.0), 2.96, 0.20, 16, "court_stone_dark",
            cap_swatch="court_stone_dark")
    for i in range(16):
        a = math.tau * i / 16.0
        mark = p.mark_verts()
        p.box((2.79, 0.44, 0.0), (0.34, 0.58, 1.05), "court_stone",
              face_swatches={"py": "court_stone", "ny": "court_stone_dark"})
        p.swing(mark, a)
        mark = p.mark_verts()
        p.box((2.79, 0.755, 0.0), (0.46, 0.12, 1.08), "stone_pale")
        p.swing(mark, a)
    p.prism((0.0, 0.205, 0.0), 2.58, 0.075, 16, "water",
            cap_swatch="water_light")

    # A single compact monument and four bronze spouts. The water remains a
    # still dark plane; no fake cylinders hang in mid-air.
    p.prism((0.0, 0.205, 0.0), 0.78, 0.34, 12, "court_stone_dark",
            cap_swatch="court_stone")
    p.prism((0.0, 0.525, 0.0), 0.54, 0.30, 10, "court_stone",
            top_radius=0.43, cap_swatch="stone_pale")
    p.taper((-0.0, 0.80, 0.0), (0.62, 0.62), (0.25, 0.25), 0.94,
            "court_stone", cap_top=True, cap_bottom=False,
            face_swatches={"py": "stone_pale"})
    p.prism((0.0, 1.72, 0.0), 0.24, 0.18, 8, "lock",
            top_radius=0.10, cap_swatch="handle")
    for i in range(4):
        a = math.tau * i / 4.0
        mark = p.mark_verts()
        p.box((0.48, 1.03, 0.0), (0.38, 0.15, 0.16), "lock")
        p.prism((0.69, 0.99, 0.0), 0.09, 0.11, 8, "handle_dark",
                cap_swatch="handle")
        p.swing(mark, a)
    return p, p.finish(material)


def build_gate_pier(material):
    p = bb.Part("lp_court_gate_pier")
    p.box((0.0, 0.16, 0.0), (1.46, 0.32, 1.46), "court_stone_dark")
    p.taper((0.0, 0.30, 0.0), (1.22, 1.22), (1.08, 1.08), 2.58,
            "court_stone", cap_top=True, cap_bottom=False)
    p.box((0.0, 2.96, 0.0), (1.40, 0.22, 1.40), "stone_pale")
    p.taper((0.0, 3.05, 0.0), (1.18, 1.18), (0.58, 0.58), 0.34,
            "court_stone", cap_top=True)
    # Lantern housing, with real posts and dark glazing rather than a glow cube.
    for x in (-0.18, 0.18):
        for z in (-0.18, 0.18):
            p.box((x, 3.64, z), (0.045, 0.52, 0.045), "handle_dark")
    for axis in (-1, 1):
        p.panel((axis * 0.205, 3.64, 0.0), (0.34, 0.40), "glass_sheen",
                "px" if axis > 0 else "nx")
        p.panel((0.0, 3.64, axis * 0.205), (0.34, 0.40), "glass_sheen",
                "pz" if axis > 0 else "nz")
    p.box((0.0, 3.38, 0.0), (0.48, 0.08, 0.48), "handle_dark")
    p.taper((0.0, 3.88, 0.0), (0.54, 0.54), (0.12, 0.12), 0.22,
            "handle_dark", cap_top=True)
    return p, p.finish(material)


def build_gate_leaf(material):
    p = bb.Part("lp_court_gate_leaf")
    # Origin is hinge axis at floor; leaf extends towards local -Z.
    p.box((0.0, 0.34, -1.35), (0.09, 0.13, 2.70), "handle_dark")
    p.box((0.0, 2.10, -1.35), (0.09, 0.13, 2.70), "handle_dark")
    for i in range(8):
        z = -0.28 - i * 0.33
        p.prism((0.0, 0.36, z), 0.035, 1.78, 6, "carcass_dark",
                cap_swatch="handle_dark")
        p.prism((0.0, 2.12, z), 0.060, 0.18, 6, "lock",
                top_radius=0.0, cap_swatch="lock")
    p.box((0.0, 1.24, -2.63), (0.11, 1.88, 0.10), "handle_dark")
    return p, p.finish(material)


def build_fence_section(material):
    p = bb.Part("lp_court_fence_section")
    # End posts reach the ground; the rails and pickets keep a deliberate
    # 240 mm drainage gap rather than hovering without anything supporting them.
    for x in (-1.72, 1.72):
        p.prism((x, 0.0, 0.0), 0.070, 1.82, 8, "carcass_dark",
                cap_swatch="handle_dark")
    p.box((0.0, 0.32, 0.0), (3.50, 0.16, 0.16), "handle_dark")
    p.box((0.0, 1.55, 0.0), (3.50, 0.12, 0.14), "handle_dark")
    for i in range(9):
        x = -1.60 + i * 0.40
        p.prism((x, 0.36, 0.0), 0.032, 1.40, 6, "carcass_dark",
                cap_swatch="handle_dark")
        p.prism((x, 1.73, 0.0), 0.052, 0.17, 6, "lock",
                top_radius=0.0, cap_swatch="lock")
    return p, p.finish(material)


def build_bench(material):
    p = bb.Part("lp_forecourt_bench")
    # Four slats and cast supports make the object read as a bench, not two planks.
    for i in range(4):
        z = -0.27 + i * 0.18
        p.box((0.0, 0.47, z), (3.40, 0.10, 0.14), "wood",
              face_swatches={"py": "wood_light", "ny": "wood_dark"})
    for i in range(4):
        y = 0.65 + i * 0.14
        p.box((0.0, y, 0.35), (3.40, 0.10, 0.08), "wood",
              face_swatches={"pz": "wood_light", "nz": "wood_dark"})
    for x in (-1.42, 1.42):
        p.box((x, 0.24, 0.0), (0.12, 0.48, 0.62), "handle_dark")
        p.box((x, 0.76, 0.35), (0.10, 0.64, 0.09), "handle_dark")
        p.box((x, 0.56, 0.0), (0.12, 0.10, 0.92), "handle_dark")
    return p, p.finish(material)


BUILDERS = (build_garden, build_fountain, build_gate_pier, build_gate_leaf,
            build_fence_section, build_bench)
BUDGET = {"lp_forecourt_garden": 5200, "lp_court_fountain": 1600,
          "lp_court_gate_pier": 500, "lp_court_gate_leaf": 500,
          "lp_court_fence_section": 500, "lp_forecourt_bench": 500}


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
        # A swinging gate leaf hangs 275 mm over the paving and is supported
        # by the adjacent pier, so its mesh is intentionally above its floor
        # origin. Every freestanding module must touch the origin plane.
        if part.name != "lp_court_gate_leaf" and abs(lo[1]) > 1e-4:
            failures.append("%s floor %.4f" % (part.name, lo[1]))
        if part.tris > BUDGET[part.name]:
            failures.append("%s %d tris > %d" %
                            (part.name, part.tris, BUDGET[part.name]))
        rows.append({"module": part.name, "size": [round(v, 4) for v in size],
                     "triangles": part.tris, "bytes": os.path.getsize(path)})
        bpy.data.objects.remove(obj, do_unlink=True)
    with open(REPORT_PATH, "w", encoding="utf-8") as fh:
        json.dump(rows, fh, indent=2)
    for row in rows:
        print("MODEL", row["module"], "x".join("%.3f" % v for v in row["size"]),
              row["triangles"], "tris", row["bytes"], "bytes")
    if failures:
        for line in failures:
            print("FAIL", line)
        raise SystemExit("forecourt build failed")
    print("BUILD_OK", len(rows), "models")


if __name__ == "__main__":
    main()
