"""Build the low-poly .glb props for museum-liminal.

Run it with the Windows Python (no packages needed, no Blender needed):

    python tools\\lowpoly\\build_props.py

Every model is written to models/lowpoly/<name>.glb and picked up by
MapModels.place("<name>", ...). Godot imports .glb on the next editor open or
--import pass; no manual import step.

BATCH 1 -- CABINETS ("shkafy")
------------------------------
The four things the museum keeps putting on screen and getting wrong:

    lp_metal_locker    two-door steel locker      hide locker, staff lockers
    lp_filing_cabinet  four-drawer filing cabinet archive, watcher office
    lp_shelf_unit      open steel shelving bay    storage, archive
    lp_key_cabinet     wall-mounted key box       watcher office (WALL-MOUNTED)

Why these read better than the primitives they replace:

  * Tapered plinths and flared cornices. Every procedural cabinet in
    game/props/ is a stack of axis-aligned boxes, so it reads as a stack of
    boxes. A plinth that kicks out 30 mm as it rises and a lid that oversails
    the carcass by 30 mm is the whole difference between "furniture" and
    "cuboid", and it costs 8 triangles.
  * Painted detail instead of modelled detail. Vent slots, drawer labels, the
    shadow line between two doors and the rust at the kickplate are flat quads
    sitting 2 mm proud of the surface, not geometry. Fifty triangles buys the
    read of five hundred.
  * Hardware that catches light. Handles and hinges stand off the door face by
    30-50 mm, so the hard point lights this game uses throw a real shadow
    across the door instead of leaving a flat panel.

ORIENTATION -- read this before placing one
-------------------------------------------
Forward is -Z, so every cabinet's doors, drawers and open shelf mouth face -Z
at rotation_y_deg = 0. Standing a cabinet against a wall means turning it to
face AWAY from that wall:

    wall behind it at north (-Z)  ->  rotation_y_deg = 180
    wall behind it at south (+Z)  ->  rotation_y_deg = 0
    wall behind it at west  (-X)  ->  rotation_y_deg = 90
    wall behind it at east  (+X)  ->  rotation_y_deg = 270

Get this wrong and you get exactly the defect the audit keeps flagging: a
cabinet showing its blank back to the room, or a monitor facing a wall.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from glb import Mesh, write_glb  # noqa: E402

# tools/lowpoly/build_props.py -> tools/lowpoly -> tools -> repository root.
REPO_ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(REPO_ROOT, "models", "lowpoly")


# =========================================================================
# lp_metal_locker -- 0.90 x 2.00 x 0.50 m, doors face -Z
# =========================================================================
def build_metal_locker():
    m = Mesh("lp_metal_locker")

    # Plinth: kicks OUTWARD as it rises, so the cabinet sits on a shadow
    # instead of meeting the floor with a hard seam.
    m.taper((0.0, 0.0, 0.0), (0.82, 0.42), (0.88, 0.48), 0.10, "plinth",
            cap_top=False)

    # Carcass. The -Z face is the recess the doors sit in front of; it is
    # darker so the 20 mm gap between the doors reads as depth.
    m.box((0.0, 1.01, 0.0), (0.90, 1.82, 0.50), "carcass",
          faces=("px", "nx", "pz", "nz"),
          face_swatches={"nz": "carcass_dark",
                         "px": "carcass_side", "nx": "carcass_side"})

    # Cornice + lid: oversails the carcass by 30 mm per side.
    m.taper((0.0, 1.92, 0.0), (0.90, 0.50), (0.96, 0.56), 0.05, "top_cap",
            cap_top=False)
    m.box((0.0, 1.985, 0.0), (0.96, 0.03, 0.56), "top_cap",
          faces=("px", "nx", "py", "pz", "nz"))

    # Shadow line down the door gap, painted on the carcass recess.
    m.panel((0.0, 1.00, -0.252), (0.020, 1.72), "shadow", axis="nz")

    door_front = -0.268
    for side in (-1, 1):
        cx = side * 0.2225
        inner = "px" if side < 0 else "nx"
        m.box((cx, 1.00, -0.2505), (0.425, 1.72, 0.035), "door",
              faces=("px", "nx", "py", "ny", "nz"),
              face_swatches={inner: "door_dark",
                             "py": "door_dark", "ny": "door_dark"})

        # Three louvre slots near the top of each door.
        for k in range(3):
            m.panel((cx, 1.74 - 0.04 * k, door_front - 0.002),
                    (0.24, 0.014), "shadow", axis="nz")

        # Hinges on the outer edge, standing 6 mm proud.
        for hy in (0.35, 1.65):
            m.box((side * 0.428, hy, door_front + 0.006),
                  (0.020, 0.090, 0.032), "hinge",
                  faces=("px", "nx", "py", "ny", "nz"))

    # Handles: vertical bars either side of the gap, 50 mm off the face, so
    # the room's point lights throw a bar of shadow across the door.
    for side in (-1, 1):
        m.box((side * 0.055, 1.02, door_front - 0.025),
              (0.028, 0.200, 0.050), "handle",
              faces=("px", "nx", "py", "ny", "nz"))

    # Lock on the left leaf only, and one paper label on the right.
    m.panel((-0.055, 0.86, door_front - 0.002), (0.050, 0.050), "lock",
            axis="nz")
    m.panel((0.2225, 1.50, door_front - 0.002), (0.150, 0.050), "label",
            axis="nz")

    # Wear: rust at the kickplate, grime down one flank. Small, off-centre,
    # never symmetrical -- symmetry is what makes dirt look like a decal.
    # Three unequal patches, two of them sharing an edge so they read as one
    # ragged L rather than a rectangle. The first pass used a single 0.30 x
    # 0.12 quad and it looked like a sticker on the door.
    m.panel((-0.255, 0.225, door_front - 0.002), (0.175, 0.100), "rust",
            axis="nz")
    m.panel((-0.115, 0.180, door_front - 0.002), (0.105, 0.062), "rust",
            axis="nz")
    m.panel((0.285, 0.150, door_front - 0.002), (0.120, 0.058), "rust",
            axis="nz")
    m.panel((-0.452, 0.62, 0.06), (0.24, 0.34), "grime", axis="nx")
    return m


# =========================================================================
# lp_filing_cabinet -- 0.46 x 1.32 x 0.62 m, drawers face -Z
# =========================================================================
def build_filing_cabinet():
    m = Mesh("lp_filing_cabinet")

    m.taper((0.0, 0.0, 0.0), (0.40, 0.56), (0.44, 0.60), 0.07, "plinth",
            cap_top=False)
    m.box((0.0, 0.66, 0.0), (0.46, 1.18, 0.62), "carcass",
          faces=("px", "nx", "pz", "nz"),
          face_swatches={"nz": "carcass_dark",
                         "px": "carcass_side", "nx": "carcass_side"})
    m.box((0.0, 1.285, 0.0), (0.48, 0.07, 0.64), "top_cap",
          faces=("px", "nx", "py", "pz", "nz"))

    front = -0.33
    for cy in (0.2385, 0.5195, 0.8005, 1.0815):
        # Drawer front, standing 20 mm proud of the carcass.
        m.box((0.0, cy, -0.32), (0.42, 0.265, 0.020), "door",
              faces=("px", "nx", "py", "ny", "nz"),
              face_swatches={"py": "door_dark", "ny": "door_dark"})
        # Recessed pull, then the bar itself in front of it.
        m.panel((0.0, cy + 0.072, front - 0.002), (0.170, 0.038), "shadow",
                axis="nz")
        m.box((0.0, cy + 0.072, front - 0.019), (0.180, 0.022, 0.034),
              "handle", faces=("px", "nx", "py", "ny", "nz"))
        # Card holder. Four small warm rectangles is the detail that says
        # "archive" without a single extra solid.
        m.panel((0.0, cy - 0.062, front - 0.002), (0.100, 0.032), "label",
                axis="nz")

    m.panel((0.232, 0.34, 0.10), (0.20, 0.26), "grime", axis="px")
    return m


# =========================================================================
# lp_shelf_unit -- 1.00 x 1.90 x 0.42 m, open face towards -Z
# =========================================================================
def build_shelf_unit():
    m = Mesh("lp_shelf_unit")

    # Four uprights.
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box((sx * 0.4775, 0.95, sz * 0.1875), (0.045, 1.90, 0.045),
                  "carcass", faces=("px", "nx", "py", "pz", "nz"))

    # Five decks, each with a folded front lip. The lip is what stops sheet
    # shelving reading as five floating planks.
    for sy in (0.16, 0.58, 1.00, 1.42, 1.84):
        m.box((0.0, sy, 0.0), (1.00, 0.028, 0.42), "carcass_side",
              face_swatches={"py": "carcass", "ny": "carcass_dark"})
        m.box((0.0, sy - 0.030, -0.200), (1.00, 0.048, 0.020), "carcass",
              faces=("px", "nx", "py", "ny", "nz"))

    # Back cross-braces, corner to corner of the back frame.
    #
    # The angle and the length are not free choices. Rotating a box of length L
    # by theta about Z gives it an X extent of L*sin(theta), so a brace that is
    # too long or too steep shoves the model's bounding box out past its own
    # uprights -- the first version was 1.94 m at 58 degrees and made a 1.00 m
    # shelving bay measure 1.66 m wide. The frame is 0.91 m between posts and
    # 1.68 m between the bottom and top decks, so the true diagonal is 1.906 m
    # at 28.4 degrees off vertical, and the unit stays 1.00 m wide as designed.
    for sign in (1, -1):
        m.box((0.0, 1.00, 0.1875), (0.022, 1.906, 0.014), "brace",
              rot=(0.0, 0.0, sign * 28.4))

    m.panel((0.0, 0.176, 0.0), (0.34, 0.22), "grime", axis="py")
    m.panel((-0.30, 1.016, 0.04), (0.26, 0.18), "grime", axis="py")
    return m


# =========================================================================
# lp_key_cabinet -- 0.44 x 0.56 x 0.11 m, WALL-MOUNTED
# =========================================================================
# Origin is the centre of the BACK face, the bit that touches the wall, and
# the body hangs towards -Z. So place() gets a point ON the wall surface, and
# rotation_y_deg turns the box to face out of that wall using the same table
# as the floor cabinets above.
def build_key_cabinet():
    m = Mesh("lp_key_cabinet")

    m.box((0.0, 0.0, -0.055), (0.44, 0.56, 0.11), "carcass",
          faces=("px", "nx", "py", "ny", "nz"),
          face_swatches={"nz": "carcass_dark"})
    m.box((0.0, 0.0, -0.117), (0.40, 0.52, 0.024), "door",
          faces=("px", "nx", "py", "ny", "nz"),
          face_swatches={"py": "door_dark", "ny": "door_dark"})

    # Glazed panel: frame first, then dead glass 1 mm in front of it.
    m.panel((0.0, 0.030, -0.1305), (0.320, 0.380), "door_dark", axis="nz")
    m.panel((0.0, 0.030, -0.1315), (0.280, 0.340), "glass_dead", axis="nz")
    # Without this the dead glass reads as a hole punched through the door.
    # One narrow off-centre band of a lighter value is enough to say "there is
    # a pane here" at the distance the player ever sees this box from.
    m.panel((-0.072, 0.055, -0.1325), (0.042, 0.270), "glass_sheen",
            axis="nz")

    for hy in (-0.19, 0.19):
        m.box((-0.205, hy, -0.118), (0.018, 0.060, 0.026), "hinge",
              faces=("px", "nx", "py", "ny", "nz"))

    m.box((0.175, -0.020, -0.144), (0.022, 0.090, 0.030), "handle",
          faces=("px", "nx", "py", "ny", "nz"))
    m.panel((0.175, -0.150, -0.1315), (0.035, 0.035), "lock", axis="nz")
    m.panel((0.0, -0.215, -0.1315), (0.140, 0.040), "label", axis="nz")
    return m


# =========================================================================

# =========================================================================
# lp_door_leaf -- one leaf of a back-of-house double door.
#
# THE ORIGIN IS THE HINGE AXIS AT FLOOR LEVEL, not the centre of a
# footprint. FirstMuseumMap parents this model to a pivot and swings the
# pivot, so x = 0 must be the line the door turns about: the leaf runs from
# there towards +X and its faces look along +-Z. That is also why MODELS
# registers it as "wall" -- the floor check wants the lowest geometry on the
# origin plane, and a door hangs 50 mm clear of its threshold.
#
# 0.86 (hinge axis -> free edge) x 2.42 (h) x 0.055 (thick), matching the
# primitive leaves it replaces. Frame and panel rather than a slab with
# painted seams: this is the one prop in the museum the player stands half a
# metre from and watches move.
# =========================================================================
def build_door_leaf():
    m = Mesh("lp_door_leaf")
    w = 0.86
    y0 = 0.05            # threshold gap under the leaf
    y1 = 2.47            # head of the leaf
    t = 0.055
    stile = 0.15
    # Members interpenetrate by this much, so no two faces are ever flush --
    # the reason every jamb in the museum was flickering last pass.
    over = 0.004

    # Stiles: full height, one on the hinge line, one at the free edge.
    for cx in (stile * 0.5, w - stile * 0.5):
        m.box((cx, (y0 + y1) * 0.5, 0.0), (stile, y1 - y0, t), "wood",
              face_swatches={"px": "wood_dark", "nx": "wood_dark",
                             "py": "wood_dark", "ny": "wood_dark"})

    # Rails span between the stiles and are buried in them at both ends, so
    # their +-X faces are dropped. Top and bottom sit 1 mm inside the stile
    # ends rather than flush with them.
    rail_x = w * 0.5
    rail_w = w - stile * 2.0 + over * 2.0
    rails = ((y1 - 0.09 - 0.001, 0.18),
             (1.30, 0.14),
             (y0 + 0.17 + 0.001, 0.34))
    for ry, rh in rails:
        m.box((rail_x, ry, 0.0), (rail_w, rh, t), "wood",
              faces=("py", "ny", "pz", "nz"),
              face_swatches={"py": "wood_dark", "ny": "wood_dark"})

    # Two recessed panels, 12 mm thinner than the frame on each face. Only
    # the two large faces are emitted; the edges are inside the frame.
    panels = ((1.83, 2.29 - 1.37 + over * 2.0),
              (0.81, 1.23 - 0.39 + over * 2.0))
    for py, ph in panels:
        m.box((rail_x, py, 0.0), (rail_w, ph, t - 0.024), "wood_dark",
              faces=("pz", "nz"))

    # Three knuckles on the pivot line. Half of each stands proud of the
    # leaf edge, which is where a real hinge lives.
    for hy in (0.35, 1.30, 2.25):
        m.cylinder((0.0, hy, 0.0), 0.024, 0.10, 6, "hinge",
                   cap_swatch="handle_dark")

    # Lever handle, rose and escutcheon on both faces.
    for side in (-1, 1):
        face = side * (t * 0.5)
        axis = "pz" if side > 0 else "nz"
        m.box((w - 0.09, 1.05, face + side * 0.008),
              (0.085, 0.085, 0.016), "handle_dark")
        m.box((w - 0.165, 1.05, face + side * 0.030),
              (0.150, 0.030, 0.030), "handle")
        m.panel((w - 0.09, 0.90, face + side * 0.002), (0.045, 0.055),
                "lock", axis=axis)
        # Kick plate over the bottom rail: the part of a service door that
        # is opened with a foot and a trolley.
        m.panel((rail_x, 0.22, face + side * 0.002), (rail_w - 0.02, 0.24),
                "handle_dark", axis=axis)

    # One paper sign and unequal wear, on one face only. Symmetrical dirt
    # reads as a decal.
    m.panel((rail_x, 1.75, t * 0.5 + 0.003), (0.140, 0.050), "label",
            axis="pz")
    m.panel((0.30, 0.44, t * 0.5 + 0.002), (0.170, 0.090), "grime",
            axis="pz")
    m.panel((0.47, 0.40, t * 0.5 + 0.002), (0.100, 0.055), "grime",
            axis="pz")
    m.panel((w - 0.28, 0.38, -t * 0.5 - 0.002), (0.130, 0.070), "rust",
            axis="nz")
    return m


# =========================================================================

MODELS = (
    ("lp_metal_locker", build_metal_locker, False),
    ("lp_filing_cabinet", build_filing_cabinet, False),
    ("lp_shelf_unit", build_shelf_unit, False),
    ("lp_key_cabinet", build_key_cabinet, True),
    # "wall" only means "do not demand a floor-level origin"; this one
    # hangs from a hinge line. See the note above build_door_leaf.
    ("lp_door_leaf", build_door_leaf, True),
)

# Ceilings from the house style in glb.py. A cabinet that blows this budget is
# a cabinet built out of solids where painted quads would have done.
TRI_BUDGET = 400


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    failed = 0
    print("%-20s %6s %6s %9s  %-22s %s"
          % ("model", "tris", "verts", "bytes", "size w/h/d (m)", "mount"))
    print("-" * 78)
    for name, builder, wall in MODELS:
        mesh = builder()
        if mesh.name != name:
            raise ValueError("%s builds a mesh named %s" % (name, mesh.name))
        path = os.path.join(OUT_DIR, name + ".glb")
        stats = write_glb(path, mesh, wall_mounted=wall)
        over = "  <-- OVER BUDGET" if stats["tris"] > TRI_BUDGET else ""
        if over:
            failed += 1
        print("%-20s %6d %6d %9d  %5.2f %5.2f %5.2f        %s%s"
              % (name, stats["tris"], stats["verts"], stats["bytes"],
                 stats["size"][0], stats["size"][1], stats["size"][2],
                 "wall" if wall else "floor", over))
    print("-" * 78)
    print("wrote %d models to %s" % (len(MODELS), OUT_DIR))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
