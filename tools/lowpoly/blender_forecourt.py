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


def _segmented_ring(p, centre_y, radius, tube, segments, swatch, pitch=0.0):
    """Faceted armillary ring built from tangent boxes, then tilted as one."""
    ring_mark = p.mark_verts()
    tangent = math.tau * radius / float(segments) * 1.06
    for i in range(segments):
        a = math.tau * i / float(segments)
        mark = p.mark_verts()
        # At +X the tangent runs along Z; swing() carries both position and
        # orientation around Y, closing the ring without crossed radial bars.
        p.box((radius, centre_y, 0.0), (tube, tube, tangent), swatch)
        p.swing(mark, a)
    if abs(pitch) > 0.001:
        p.pitch(ring_mark, (0.0, centre_y, 0.0), pitch)


def build_fountain(material):
    p = bb.Part("lp_court_fountain")
    # V2 is an armillary court fountain: the footprint and low collision stay
    # unchanged, but the centre now has a readable museum-scale silhouette.
    p.prism((0.0, 0.0, 0.0), 2.96, 0.18, 20, "court_stone_dark",
            cap_swatch="court_stone_dark")
    for i in range(20):
        a = math.tau * i / 20.0
        mark = p.mark_verts()
        p.box((2.80, 0.25, 0.0), (0.32, 0.42, 0.92), "court_stone",
              face_swatches={"py": "stone_pale", "ny": "court_stone_dark"})
        p.swing(mark, a)
        mark = p.mark_verts()
        p.box((2.80, 0.49, 0.0), (0.44, 0.12, 0.94), "stone_pale")
        p.swing(mark, a)
    p.prism((0.0, 0.19, 0.0), 2.60, 0.055, 20, "water",
            cap_swatch="water_light")

    # Stepped octagonal pedestal, kept low enough that the rings float above
    # the pool rather than turning back into the rejected tiered cake.
    p.prism((0.0, 0.19, 0.0), 0.82, 0.27, 12, "court_stone_dark",
            cap_swatch="court_stone")
    p.taper((0.0, 0.44, 0.0), (1.18, 1.18), (0.76, 0.76), 0.43,
            "court_stone", cap_top=True, cap_bottom=False,
            face_swatches={"py": "stone_pale"})
    p.prism((0.0, 0.84, 0.0), 0.13, 0.60, 8, "lock",
            top_radius=0.105, cap_swatch="handle")

    # Faceted globe and four bronze rings. The same atlas material is kept,
    # but the geometry catches both daylight and the new gate/street lighting.
    p.taper((0.0, 1.43, 0.0), (0.14, 0.14), (0.58, 0.58), 0.30,
            "court_stone", cap_bottom=True)
    p.taper((0.0, 1.73, 0.0), (0.58, 0.58), (0.14, 0.14), 0.30,
            "court_stone", cap_top=True, cap_bottom=False,
            face_swatches={"py": "stone_pale"})
    for tilt in (0.0, 58.0, -58.0, 90.0):
        _segmented_ring(p, 1.73, 0.78, 0.055, 14, "lock", tilt)

    # Four short mouths and four impact ripples give the object a water story
    # without reviving the old rigid airborne tube forest.
    for i in range(4):
        a = math.tau * i / 4.0
        mark = p.mark_verts()
        p.box((0.64, 0.96, 0.0), (0.42, 0.13, 0.16), "lock")
        p.prism((0.88, 0.895, 0.0), 0.085, 0.11, 8, "handle_dark",
                cap_swatch="handle")
        p.prism((1.42, 0.246, 0.0), 0.24, 0.018, 12, "water",
                cap_swatch="water_light")
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

    # A real four-sided lantern: sill, corner posts, glazed panels, cross
    # mullions, crown, pitched roof and finial. Runtime adds only the tiny bulb
    # and OmniLight3D inside this authored housing.
    p.box((0.0, 3.39, 0.0), (0.56, 0.10, 0.56), "handle_dark")
    p.prism((0.0, 3.36, 0.0), 0.31, 0.10, 8, "lock",
            top_radius=0.27, cap_swatch="handle")
    for x in (-0.205, 0.205):
        for z in (-0.205, 0.205):
            p.box((x, 3.70, z), (0.050, 0.62, 0.050), "handle_dark")
    for axis in (-1, 1):
        p.panel((axis * 0.231, 3.70, 0.0), (0.36, 0.48), "glass_sheen",
                "px" if axis > 0 else "nx")
        p.panel((0.0, 3.70, axis * 0.231), (0.36, 0.48), "glass_sheen",
                "pz" if axis > 0 else "nz")
        # Cross mullions sit proud of the glass on every side.
        p.box((axis * 0.234, 3.70, 0.0), (0.022, 0.045, 0.39), "handle")
        p.box((0.0, 3.70, axis * 0.234), (0.39, 0.045, 0.022), "handle")
    p.box((0.0, 4.02, 0.0), (0.58, 0.09, 0.58), "handle_dark")
    p.taper((0.0, 4.055, 0.0), (0.66, 0.66), (0.16, 0.16), 0.25,
            "handle_dark", cap_top=True)
    p.prism((0.0, 4.28, 0.0), 0.085, 0.15, 8, "lock",
            top_radius=0.0, cap_swatch="lock")
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


def build_urn(material):
    p = bb.Part("lp_court_urn")
    p.box((0.0, 0.10, 0.0), (0.78, 0.20, 0.78), "court_stone_dark")
    p.taper((0.0, 0.18, 0.0), (0.62, 0.62), (0.48, 0.48), 0.30,
            "court_stone", cap_top=True, cap_bottom=False)
    p.prism((0.0, 0.46, 0.0), 0.16, 0.18, 10, "court_stone_dark",
            top_radius=0.20, cap_swatch="court_stone")
    p.taper((0.0, 0.60, 0.0), (0.42, 0.42), (0.78, 0.78), 0.28,
            "court_stone", cap_top=True, cap_bottom=False)
    p.box((0.0, 0.89, 0.0), (0.86, 0.10, 0.86), "stone_pale")
    p.prism((0.0, 0.945, 0.0), 0.36, 0.045, 12, "court_soil",
            cap_swatch="court_soil")
    # Upright leaves replace the old single foliage sphere.
    for i in range(7):
        a = math.tau * i / 7.0
        r = 0.12 if i % 2 == 0 else 0.22
        p.prism((math.cos(a) * r, 0.96, math.sin(a) * r), 0.075,
                0.50 if i % 2 == 0 else 0.36, 6,
                "leaf" if i % 2 == 0 else "leaf_dark", top_radius=0.018)
    return p, p.finish(material)


def build_hours_sign(material):
    p = bb.Part("lp_hours_sign")
    for x in (-0.58, 0.58):
        p.box((x, 0.62, 0.0), (0.08, 1.24, 0.08), "handle_dark")
        p.box((x, 0.04, 0.0), (0.30, 0.08, 0.30), "carcass_dark")
    p.box((0.0, 1.37, 0.0), (1.58, 0.76, 0.12), "carcass_dark")
    p.box((0.0, 1.37, -0.066), (1.40, 0.58, 0.025), "stone_pale")
    p.box((0.0, 1.77, 0.0), (1.70, 0.08, 0.16), "lock")
    return p, p.finish(material)


def build_bike_rack(material):
    p = bb.Part("lp_bike_rack")
    for i in range(5):
        x = -1.28 + i * 0.64
        for z in (-0.34, 0.34):
            p.box((x, 0.43, z), (0.070, 0.86, 0.070), "handle")
            p.box((x, 0.035, z), (0.22, 0.07, 0.22), "carcass_dark")
        p.box((x, 0.86, 0.0), (0.070, 0.070, 0.72), "handle")
        # Short bevel-like shoulders make the rectangular hoop read as bent tube.
        for z, angle in ((-0.30, -42.0), (0.30, 42.0)):
            mark = p.mark_verts()
            p.box((x, 0.80, z), (0.072, 0.22, 0.072), "handle")
            p.pitch(mark, (x, 0.80, z), angle)
    return p, p.finish(material)


def build_street_bin(material):
    p = bb.Part("lp_street_bin")
    p.prism((0.0, 0.0, 0.0), 0.38, 0.10, 12, "carcass_dark",
            top_radius=0.35, cap_swatch="handle_dark")
    p.prism((0.0, 0.08, 0.0), 0.34, 0.78, 12, "court_hedge",
            top_radius=0.30, cap_swatch="leaf_dark")
    p.prism((0.0, 0.84, 0.0), 0.39, 0.09, 12, "carcass_dark",
            top_radius=0.36, cap_swatch="handle")
    p.prism((0.0, 0.915, 0.0), 0.29, 0.045, 12, "shadow",
            cap_swatch="shadow")
    p.box((0.0, 0.52, -0.326), (0.28, 0.22, 0.025), "handle_dark")
    return p, p.finish(material)


def build_fire_hydrant(material):
    p = bb.Part("lp_fire_hydrant")
    p.prism((0.0, 0.0, 0.0), 0.27, 0.10, 10, "carcass_dark",
            top_radius=0.23, cap_swatch="handle_dark")
    p.prism((0.0, 0.08, 0.0), 0.18, 0.54, 10, "flower_red",
            top_radius=0.20, cap_swatch="flower_red")
    p.prism((0.0, 0.60, 0.0), 0.25, 0.11, 10, "flower_red",
            top_radius=0.20, cap_swatch="handle")
    p.prism((0.0, 0.70, 0.0), 0.19, 0.16, 10, "flower_red",
            top_radius=0.045, cap_swatch="handle_dark")
    for side in (-1.0, 1.0):
        p.box((side * 0.22, 0.45, 0.0), (0.20, 0.20, 0.20), "flower_red")
        p.box((side * 0.34, 0.45, 0.0), (0.08, 0.14, 0.14), "handle_dark")
    return p, p.finish(material)


BUILDERS = (build_garden, build_fountain, build_gate_pier, build_gate_leaf,
            build_fence_section, build_bench, build_urn, build_hours_sign,
            build_bike_rack, build_street_bin, build_fire_hydrant)
BUDGET = {"lp_forecourt_garden": 5200, "lp_court_fountain": 2600,
          "lp_court_gate_pier": 800, "lp_court_gate_leaf": 500,
          "lp_court_fence_section": 500, "lp_forecourt_bench": 500,
          "lp_court_urn": 500, "lp_hours_sign": 300,
          "lp_bike_rack": 900, "lp_street_bin": 300,
          "lp_fire_hydrant": 300}


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
