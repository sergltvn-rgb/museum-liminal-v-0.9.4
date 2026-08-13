"""Blender-authored low-poly street modules for museum-liminal -- SCHEME V2.

RUN IT LIKE THIS (Blender 5.2 is NOT on PATH):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/lowpoly/blender_street_v2.py

Then, MANDATORY, or Godot never sees the files, MapModels.place() hands back
null, the old primitives get drawn instead and the test suite still passes:

    Godot_v4.7-stable_win64_console.exe --path . --headless --import

WHY THIS FILE REPLACES tools/lowpoly/export_street_modules.py
-------------------------------------------------------------
That exporter slices modules out of models/street/street_master.blend, which
is the P0 master. P0 put the carriageway at z 58.0..65.0, and STREET_SCHEME_V2
puts it back at z 55.5..62.5 because all six segments of _drive_track in
game/FirstMuseumMap.gd drive down z 57.2 and the shot-4 camera at z 61.6 is
commented "static camera on the far edge of the road". The master's geometry
is therefore at the wrong coordinates and carries pieces V2 deletes outright
(far pavement, both crossings, both visitor pockets, the second lamp row).
Filtering cannot fix a coordinate; the modules are rebuilt here instead.

MODULE LIST -- eight, which is what STREET_SCHEME_V2 section 9 item 7 approved
------------------------------------------------------------------------------
    lp_street_road_20      R01  20 m carriageway tile, 7.0 wide
    lp_street_walk_20      S01  20 m museum-side pavement tile, 3.1 wide
    lp_street_verge_20     V01  20 m gravel verge tile, 2.1 wide
    lp_street_bay_2         L01/B01  2 m lay-by tile, 2.5 deep
    lp_street_drive_apron  P01  5.5 x 5.0 vehicle crossover into the car park
    lp_street_bollard      V02  verge post
    lp_street_lamp              4.5 m cast-iron lamp, 1.83 m neck over the lane
    lp_street_shelter      B02  bus shelter, museum side

lp_street_bridge.glb (BG01) is NOT rebuilt. The P0 model is a bridge and stays
correct as a shape; only its placement moves 2.5 m with the carriageway, which
is a StreetProps change, not a modelling one.

L02, the "pavement widening at the lay-by" in the V2 table, is NOT built. Its
band z 52.9..55.5 lies entirely inside S01's z 52.4..55.5, so it would be a
second surface coplanar with the pavement -- exactly the z-fighting the house
style forbids. The pavement already provides the standing area. Recorded in
WORKLOG.md rather than silently dropped.

HOUSE STYLE
-----------
Inherited wholesale from blender_build: Godot coordinates (+X right, +Y up,
-Z forward), 1 unit = 1 m, origin on the FLOOR, one material, one 128x128
palette atlas, flat shading, metallic 0 / roughness 0.92.

TILES AND WHY THEY ARE TILES
----------------------------
The street is 340 m long and the player sees it from a 30 s drive and a 40 m
walk. Three surfaces therefore ship as 20 m tiles that StreetProps repeats,
and the lay-by as a 2 m tile that serves both the 18 m car lay-by and the 14 m
bus bay. One convex hull per tile also keeps collision sane: a single 340 m
hull would be a wall.

NO TWO FACES ARE COPLANAR
-------------------------
Every add-on part is buried 5-20 mm inside whatever it lands on, and every
painted quad sits 0.3-2 mm proud of its host face, with overlapping quads kept
0.5 mm apart in height. Two surfaces sharing a plane is the shimmer this audit
round had to take out of the atrium floor, and on a road surface lit by a
low sun it is the most visible defect there is.
"""

from __future__ import annotations

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import blender_build as bb  # noqa: E402  -- Part, make_material, export_glb

OUT_DIR = bb.OUT_DIR
REPO_ROOT = bb.REPO_ROOT
REPORT_PATH = os.path.join(REPO_ROOT, "street_master_review",
                           "street_v2_modules.json")

# Tile pitches. StreetProps must use these exact numbers or the tiles gap.
TILE_LEN = 20.0
BAY_TILE_LEN = 2.0


# =========================================================================
# R01 -- lp_street_road_20, 20.0 x 0.20 x 7.0, top at local y = 0.20
# =========================================================================
# Placed at y = -0.20 so the running surface lands on world y = 0.000, which
# is the datum the whole V2 cross-section is measured from.
#
# 7.0 m is two 3.5 m lanes. The westbound lane axis is therefore 1.75 m from
# the kerb, i.e. world z 57.25 against the cut-scene's z 57.2 -- 5 cm, which
# is what the whole rebuild is for.
def build_road_tile(material):
    p = bb.Part("lp_street_road_20")

    slab = p.mark_faces()
    p.box((0.0, 0.100, 0.0), (TILE_LEN, 0.200, 7.000), "carcass_dark",
          face_swatches={"py": "carcass_dark", "ny": "shadow",
                         "pz": "carcass_side", "nz": "carcass_side"})
    body = p.new_faces(slab)
    # Chamfer the running edge. On a road this is the one line that separates
    # "asphalt" from "black rectangle": it catches a different value from the
    # top and the kerb face either side of it.
    p.bevel(p.facing(body, "py"), 0.020, "carcass_side")

    # Centre dashes: 3 m of paint on a 10 m cycle, so a 20 m tile carries two
    # and the pattern repeats seamlessly however many tiles are laid.
    for x in (-5.0, 5.0):
        p.panel((x, 0.2005, 0.0), (3.000, 0.140), "stone_pale", "py")

    # Lane edge lines, 0.2 m in from each side. 19.96 rather than 20.0 keeps
    # them clear of the 20 mm chamfer at the tile ends.
    for z in (-3.200, 3.200):
        p.panel((0.0, 0.2005, z), (19.960, 0.100), "stone_pale", "py")

    # Asymmetric wear. Deliberately not mirrored: two identical halves is what
    # makes a tiled surface read as tiled.
    p.panel((-3.400, 0.2002, -1.150), (9.200, 1.900), "grime", "py")
    p.panel((6.100, 0.2002, 1.700), (5.600, 1.400), "grime", "py")

    return p, p.finish(material)


# =========================================================================
# S01 -- lp_street_walk_20, 20.0 x 0.15 x 3.1, top at local y = 0.15
# =========================================================================
# The slab IS the kerb: 150 mm of upstand against the carriageway, which is
# why it is placed at world y = 0.000 with its top at +0.150. The road-facing
# side is +Z (the museum is at lower z, the forest at higher z).
def build_walk_tile(material):
    p = bb.Part("lp_street_walk_20")

    slab = p.mark_faces()
    p.box((0.0, 0.075, 0.0), (TILE_LEN, 0.150, 3.100), "top_cap",
          face_swatches={"py": "top_cap", "pz": "handle_dark",
                         "nz": "carcass_side", "ny": "shadow"})
    body = p.new_faces(slab)
    # Kerb nose. 14 mm is a weathered granite arris, and it is the line the
    # player walks beside for 40 m on the way to the door.
    p.bevel(p.facing(body, "py"), 0.014, "handle")

    # Slab joints every 1.25 m. Sixteen paving units per tile is what gives
    # the pavement a measurable scale from eye height.
    for i in range(15):
        p.panel((-8.750 + 1.250 * i, 0.1508, 0.0), (0.030, 3.060),
                "shadow", "py")
    # One longitudinal joint, off centre so the slabs are not squares.
    p.panel((0.0, 0.1508, 0.400), (19.960, 0.030), "shadow", "py")

    # Kerb band on the road face, and the grime that always collects in the
    # gutter line. 0.1503 keeps it 0.5 mm clear of the joints above it.
    p.panel((0.0, 0.110, 1.5505), (19.960, 0.055), "handle", "pz")
    p.panel((0.0, 0.1503, 1.300), (19.960, 0.300), "grime", "py")

    return p, p.finish(material)


# =========================================================================
# V01 -- lp_street_verge_20, 20.0 x 0.04 x 2.1, top at local y = 0.04
# =========================================================================
# What the far side of the road gets INSTEAD of the P0 far pavement. There is
# no building on that side and no destination to walk to: a gravel verge and
# then trees is what a road through forest actually has.
def build_verge_tile(material):
    p = bb.Part("lp_street_verge_20")

    slab = p.mark_faces()
    p.box((0.0, 0.020, 0.0), (TILE_LEN, 0.040, 2.100), "grime",
          face_swatches={"py": "grime", "nz": "plinth", "ny": "shadow"})
    body = p.new_faces(slab)
    p.bevel(p.facing(body, "py"), 0.010, "plinth")

    # Patchy gravel. Three irregular quads, none symmetric with another.
    p.panel((-6.200, 0.0405, -0.350), (4.200, 0.900), "plinth", "py")
    p.panel((2.400, 0.0405, 0.300), (6.000, 1.100), "plinth", "py")
    p.panel((8.000, 0.0403, -0.550), (3.000, 0.700), "carcass_side", "py")

    return p, p.finish(material)


# =========================================================================
# L01 / B01 -- lp_street_bay_2, 2.0 x 0.04 x 2.5, top at local y = 0.04
# =========================================================================
# One tile serves both lay-bys: nine of them make the 18 m car lay-by at x 8.5
# and seven make the 14 m bus bay at x 26. Both are cut into the museum-side
# edge of the carriageway, so the outer edge (local -Z) is the kerb side.
#
# This is the single most load-bearing module in the rebuild: it is what lets
# the player's car stop OUT of the running lane. In the rejected P0 port the
# car parked at z 59.6, which was the middle of the live lane.
def build_bay_tile(material):
    p = bb.Part("lp_street_bay_2")

    slab = p.mark_faces()
    p.box((0.0, 0.020, 0.0), (BAY_TILE_LEN, 0.040, 2.500), "carcass_dark",
          face_swatches={"py": "carcass_dark", "ny": "shadow"})
    body = p.new_faces(slab)
    p.bevel(p.facing(body, "py"), 0.008, "carcass_side")

    # Bay edge line along the kerb side, and the dirt that collects in a
    # parking bay nobody sweeps.
    p.panel((0.0, 0.0405, -1.100), (1.960, 0.100), "stone_pale", "py")
    p.panel((0.0, 0.0403, 0.550), (1.960, 1.100), "grime", "py")

    return p, p.finish(material)


# =========================================================================
# P01 -- lp_street_drive_apron, 5.5 x 0.08 x 5.0, top at local y = 0.08
# =========================================================================
# The car park at (42.4, 46.5) has existed for the whole project with no
# connection to the road at all. This is that connection: a dropped crossing
# at x 32 where the pavement and kerb break for vehicles. 80 mm is a dropped
# kerb, not a full 150 mm upstand, which is why it is its own module rather
# than a gap in the pavement run.
def build_drive_apron(material):
    p = bb.Part("lp_street_drive_apron")

    slab = p.mark_faces()
    p.box((0.0, 0.040, 0.0), (5.500, 0.080, 5.000), "top_cap",
          face_swatches={"py": "top_cap", "ny": "shadow"})
    body = p.new_faces(slab)
    p.bevel(p.facing(body, "py"), 0.016, "handle")

    # Construction joints where a real crossover is saw-cut.
    for z in (-1.400, 1.400):
        p.panel((0.0, 0.0808, z), (5.460, 0.035), "shadow", "py")
    p.panel((0.0, 0.0808, 0.0), (0.035, 4.960), "shadow", "py")

    # Tyre tracks, on the 2.6 m spacing of the car that uses them.
    for x in (-1.300, 1.300):
        p.panel((x, 0.0803, 0.0), (0.900, 4.960), "grime", "py")

    return p, p.finish(material)


# =========================================================================
# V02 -- lp_street_bollard, 0.18 x 0.85 x 0.18
# =========================================================================
# Marks the edge of the gravel verge every 8 m through the inhabited strip.
# Outside x -40..60 there are no bollards and no lamps: it is a forest road
# and it should read as one from the car.
def build_bollard(material):
    p = bb.Part("lp_street_bollard")

    # Cast foot, so the post is planted rather than pushed into the ground.
    p.taper((0.0, 0.0, 0.0), (0.180, 0.180), (0.140, 0.140), 0.060,
            "plinth", cap_top=True, cap_bottom=False)

    # Post. Base at 0.055 is 5 mm INSIDE the foot's top face.
    p.prism((0.0, 0.055, 0.0), 0.062, 0.760, 8, "carcass_dark",
            cap_swatch="carcass_side")

    # Reflector band, 4 mm proud of the post so it is a collar and not paint.
    p.prism((0.0, 0.620, 0.0), 0.066, 0.090, 8, "stone_pale")

    # Domed cap, buried 15 mm into the post top at 0.815.
    p.prism((0.0, 0.800, 0.0), 0.066, 0.045, 8, "carcass",
            top_radius=0.040, cap_swatch="carcass_side")

    return p, p.finish(material)


# =========================================================================
# lp_street_lamp -- 0.440 x 4.545 x 2.272 cast iron, neck towards +Z (road)
# =========================================================================
# REMADE 2026-08-13, the first version having been rejected by the user. The
# code said why before taste did: the lantern was a 0.42 x 0.13 m plate on a
# 0.76 m bracket, so a column standing at z 55.10 hung its glass at z 55.86
# while the lane the cut-scene drives down is z 57.25. The lamp lit the kerb
# and missed the road by 1.4 m. The neck now reaches 1.83 m, which puts the
# glass at z 56.93 -- under the driven lane, which is what a street lamp is
# for. Nothing measured that before, so RULES now carries reach_z.
#
# Silhouette chosen by the user: retro museum cast iron. Faceted mast, swan
# neck, lantern that narrows DOWNWARDS under a crown.
#
# THE NECK IS NOT A CONSTANT 15 DEGREES PER SEGMENT. The brief said "about
# 15", which over six segments is a quarter circle, and a quarter circle long
# enough to reach 1.8 m also rises 1.3 m: a 5.2 m lamp on a 3.9 m mast. Real
# cast-iron necks bend hard where they leave the mast and then flatten out, so
# the steps are 24, 54, 78, 94, 104, 112 degrees from vertical. The last two
# pass the horizontal, which is what makes the lantern hang rather than perch.
#
# NOT centred in Z, and that is deliberate: the column stands on the pavement
# at z 55.10 and the lantern has to hang over the carriageway. The bounding
# box is therefore lopsided and the centre_z house rule is waived for this
# model only, the same way blender_cameras waives the floor rule for a
# ceiling plate.
#
# One row, museum side only. The P0 second row lit the forest.
ARC_STEPS = (24.0, 54.0, 78.0, 94.0, 104.0, 112.0)
ARC_SEG = 0.360       # how far along the neck one segment advances
ARC_OVERLAP = 0.055   # and how much longer it is built, so the outside of
                      # every bend closes with solid overlap instead of a gap
ARC_R0 = 0.056        # neck radius at the mast head, which ends at 0.060
ARC_R1 = 0.042        # neck radius at the crown


def build_street_lamp(material):
    p = bb.Part("lp_street_lamp")

    # Cast base in two stages. The upper one starts 5 mm down inside the lower
    # and is 20 mm narrower where it emerges, so the step is a real shoulder
    # and not two faces fighting over one plane.
    p.taper((0.0, 0.0, 0.0), (0.440, 0.440), (0.360, 0.360), 0.070,
            "carcass_dark", cap_top=True, cap_bottom=False)
    p.taper((0.0, 0.065, 0.0), (0.340, 0.340), (0.300, 0.300), 0.095,
            "carcass_dark", cap_top=True, cap_bottom=False)

    # Collar. The brief stood it flush on the base top at 0.160; 10 mm lower
    # is the same silhouette without the coplanar pair the house style bans.
    p.prism((0.0, 0.150, 0.0), 0.130, 0.230, 8, "carcass_dark",
            cap_swatch="carcass_side")

    # Faceted mast, 85 -> 60 mm, head at 3.930. Foot 10 mm inside the collar,
    # same reason again.
    p.prism((0.0, 0.370, 0.0), 0.085, 3.560, 8, "carcass",
            top_radius=0.060, cap_swatch="carcass_side")

    # Swan neck. Each segment is built vertically on the end of the previous
    # one and then pitched about that same point, because pitch() turns
    # EVERYTHING made after mark_verts() about the Godot X axis, and positive
    # degrees carry the top towards +Z, i.e. the road. This toolchain has no
    # rotation about Z at all -- only swing (Y) and pitch (X) -- so a curve
    # has to be a chain of straight pieces.
    ay, az = 3.870, 0.0            # 60 mm down inside the mast head
    steps = len(ARC_STEPS)
    for i, angle in enumerate(ARC_STEPS):
        r0 = ARC_R0 + (ARC_R1 - ARC_R0) * (float(i) / float(steps))
        r1 = ARC_R0 + (ARC_R1 - ARC_R0) * (float(i + 1) / float(steps))
        mark = p.mark_verts()
        p.prism((0.0, ay, az), r0, ARC_SEG + ARC_OVERLAP, 8, "carcass",
                top_radius=r1, cap_swatch="carcass_side")
        p.pitch(mark, (0.0, ay, az), angle)
        rad = math.radians(angle)
        ay += ARC_SEG * math.cos(rad)
        az += ARC_SEG * math.sin(rad)

    # Lantern, hung under the end of the neck. The neck stops 48 mm above the
    # shoulder, inside the crown cone below, so the two are joined and not
    # merely adjacent.
    shoulder = ay - 0.048
    glass = p.mark_faces()
    p.taper((0.0, shoulder - 0.340, az), (0.260, 0.260), (0.400, 0.400),
            0.340, "glass_sheen", cap_top=True, cap_bottom=True,
            face_swatches={"py": "carcass_dark", "ny": "glass_dead"})
    # Cast rim under the glass. The rejected lamp ended in a cut-off edge;
    # this is the chamfer that tells the eye the lantern has a bottom.
    p.bevel(p.facing(p.new_faces(glass), "ny"), 0.016, "carcass_side")

    # Crown, sunk 20 mm into the shoulder.
    p.prism((0.0, shoulder - 0.020, az), 0.220, 0.120, 8, "carcass_dark",
            top_radius=0.060, cap_swatch="carcass_side")

    return p, p.finish(material)


# =========================================================================
# B02 -- lp_street_shelter, 5.0 x 2.63 x 2.2, open towards +Z (the road)
# =========================================================================
# Moved to the museum side by V2. In P0 it stood on the far pavement, so the
# only way to reach it was to cross seven metres of carriageway from a museum
# nobody was leaving on foot.
#
# The roof oversails the open front, so this model is also waived from the
# centre_z rule.
#
# COLLISION WARNING FOR StreetProps: MapModels.place() builds ONE convex hull
# per MeshInstance3D, and the convex hull of a shelter is a solid block. This
# model must have its generated hull stripped and box colliders added per
# post, or the player will be walled out of it.
def build_shelter(material):
    p = bb.Part("lp_street_shelter")

    # Pad.
    pad = p.mark_faces()
    p.box((0.0, 0.030, 0.0), (4.800, 0.060, 2.000), "top_cap",
          face_swatches={"py": "top_cap", "ny": "shadow"})
    body = p.new_faces(pad)
    p.bevel(p.facing(body, "py"), 0.012, "handle")

    # Four posts, feet 10 mm inside the pad, heads 10 mm inside the roof.
    for x in (-2.280, 2.280):
        for z in (-0.860, 0.860):
            p.prism((x, 0.050, z), 0.055, 2.450, 8, "carcass",
                    cap_swatch="carcass_side")

    # Back glazing, buried in both pad and roof.
    p.box((0.0, 1.270, -0.930), (4.500, 2.480, 0.045), "glass_dead")
    p.panel((0.0, 1.500, -0.9055), (1.200, 1.400), "glass_sheen", "pz")

    # Roof, oversailing the front by 100 mm.
    roof = p.mark_faces()
    p.box((0.0, 2.560, -0.060), (5.000, 0.140, 2.200), "carcass_dark",
          face_swatches={"py": "top_cap", "ny": "shadow"})
    rb = p.new_faces(roof)
    p.bevel(p.facing(rb, "py"), 0.030, "carcass_side")

    # Bench. Legs run 20 mm up into the seat and 15 mm down into the pad, so
    # nothing here shares a plane with anything.
    p.box((0.0, 0.470, -0.700), (3.600, 0.070, 0.420), "wood",
          face_swatches={"py": "wood_light"})
    for x in (-1.550, 1.550):
        p.box((x, 0.235, -0.700), (0.090, 0.440, 0.360), "carcass_side")

    return p, p.finish(material)


BUILDERS = (build_road_tile, build_walk_tile, build_verge_tile,
            build_bay_tile, build_drive_apron, build_bollard,
            build_street_lamp, build_shelter)

BUDGET = {
    "lp_street_road_20": 300,
    "lp_street_walk_20": 300,
    "lp_street_verge_20": 200,
    "lp_street_bay_2": 200,
    "lp_street_drive_apron": 300,
    "lp_street_bollard": 300,
    "lp_street_lamp": 600,
    "lp_street_shelter": 900,
}

# Per-model house-style rules. floor_y is checked for every model; the two
# waivers are documented in the builders above.
RULES = {
    "lp_street_road_20": {"centre_x": True, "centre_z": True},
    "lp_street_walk_20": {"centre_x": True, "centre_z": True},
    "lp_street_verge_20": {"centre_x": True, "centre_z": True},
    "lp_street_bay_2": {"centre_x": True, "centre_z": True},
    "lp_street_drive_apron": {"centre_x": True, "centre_z": True},
    "lp_street_bollard": {"centre_x": True, "centre_z": True},
    # reach_z closes the hole that let the rejected lamp through. Nothing
    # measured how far the lantern got over the road, so a 0.76 m bracket
    # passed every check while lighting the kerb. 1.70 m is the least that
    # hangs glass under the driven lane from a column standing at z 55.10.
    "lp_street_lamp": {"centre_x": True, "reach_z": 1.700},
    "lp_street_shelter": {"centre_x": True},
}

# Sizes StreetProps has to agree with. Checked here so a modelling change can
# never silently desync from the placement code.
EXPECT_SIZE = {
    "lp_street_road_20": (20.000, 0.200, 7.000),
    "lp_street_walk_20": (20.000, 0.150, 3.100),
    "lp_street_verge_20": (20.000, 0.040, 2.100),
    "lp_street_bay_2": (2.000, 0.040, 2.500),
    "lp_street_drive_apron": (5.500, 0.080, 5.000),
}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not os.path.isdir(OUT_DIR):
        os.makedirs(OUT_DIR)
    report_dir = os.path.dirname(REPORT_PATH)
    if not os.path.isdir(report_dir):
        os.makedirs(report_dir)

    material = bb.make_material()
    print("BLENDER", bpy.app.version_string)
    print("SWATCHES", len(bb.SWATCH_NAMES))
    print("OUT_DIR", OUT_DIR)

    rows = []
    report = []
    failures = []

    for builder in BUILDERS:
        part, obj = builder(material)
        path = os.path.join(OUT_DIR, part.name + ".glb")
        bb.export_glb(obj, path)

        (lo, hi) = part.bounds
        size = (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
        nbytes = os.path.getsize(path) if os.path.exists(path) else 0
        rule = RULES[part.name]

        if abs(lo[1]) > 1e-4:
            failures.append("%s: floor is at y=%.4f, must be 0"
                            % (part.name, lo[1]))
        if rule.get("centre_x") and abs(lo[0] + hi[0]) > 2e-3:
            failures.append("%s: not centred in X (%.4f .. %.4f)"
                            % (part.name, lo[0], hi[0]))
        if rule.get("centre_z") and abs(lo[2] + hi[2]) > 2e-3:
            failures.append("%s: not centred in Z (%.4f .. %.4f)"
                            % (part.name, lo[2], hi[2]))
        if rule.get("reach_z") and hi[2] < rule["reach_z"] - 2e-3:
            failures.append("%s: reaches z %.4f, needs %.4f to hang over the"
                            " lane" % (part.name, hi[2], rule["reach_z"]))
        if part.name in EXPECT_SIZE:
            want = EXPECT_SIZE[part.name]
            for axis, got, exp in zip("XYZ", size, want):
                if abs(got - exp) > 2e-3:
                    failures.append("%s: %s size %.4f, scheme says %.4f"
                                    % (part.name, axis, got, exp))
        if part.tris > BUDGET[part.name]:
            failures.append("%s: %d tris, over the %d budget"
                            % (part.name, part.tris, BUDGET[part.name]))
        if nbytes == 0:
            failures.append("%s: export produced no file" % part.name)

        rows.append((part.name, lo, hi, size, part.tris, part.quads, nbytes))
        report.append({
            "module": part.name,
            "size": [round(v, 4) for v in size],
            "lo": [round(v, 4) for v in lo],
            "hi": [round(v, 4) for v in hi],
            "triangles": part.tris,
            "faces": part.quads,
            "bytes": nbytes,
        })
        bpy.data.objects.remove(obj, do_unlink=True)

    with open(REPORT_PATH, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2, ensure_ascii=False)

    print("")
    print("%-24s %-26s %6s %6s %9s"
          % ("model", "bbox W x H x D (m)", "tris", "faces", "bytes"))
    print("-" * 78)
    for name, lo, hi, size, tris, quads, nbytes in rows:
        print("%-24s %-26s %6d %6d %9d"
              % (name, "%.3f x %.3f x %.3f" % size, tris, quads, nbytes))
        print("%-24s x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f"
              % ("", lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    print("")
    print("REPORT", REPORT_PATH)

    if failures:
        for line in failures:
            print("FAIL", line)
        raise SystemExit(
            "blender_street_v2: %d house-style violation(s)" % len(failures))

    print("BUILD_OK", len(rows), "models")


if __name__ == "__main__":
    main()
