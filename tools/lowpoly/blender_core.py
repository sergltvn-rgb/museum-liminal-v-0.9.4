"""Blender-authored low-poly containment core for museum-liminal.

RUN IT LIKE THIS (no GUI, nothing to click):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/lowpoly/blender_core.py

And then, without exception:

    Godot_v4.7-stable_win64_console.exe --path . --headless --import

Without the import step ResourceLoader.exists() answers false, MapModels.place()
returns null, AtriumProps quietly draws the primitive fallback instead -- and
every test still passes. The only proof a model actually landed is the
MeshInstance3D count in game/test_map_verification.gd moving.

WHY THIS FILE EXISTS
--------------------
The containment core is the first thing a visitor sees from the entrance
doorway and the thing the whole atrium is arranged around, and it was built out
of roughly a hundred and forty CylinderMesh / BoxMesh primitives in
AtriumProps._build_core_*. Adding more primitives to it was tried in the
previous pass -- the service rig -- and rejected, correctly: the problem was
never that the core had too few parts. The problem is what primitives cannot
do.

    * A CylinderMesh drum and the flange stacked on it meet on a shared plane.
      That is the exact same coplanar pair that makes the atrium floor shimmer,
      repeated at every one of the core's twenty-odd stacked joints, and it is
      why the core sparkles when the camera turns.
    * Nothing in the primitive core has a chamfer, so every silhouette edge is
      a hard 90 degrees. At low poly the silhouette IS the model: an unchamfered
      edge catches the same light value on both sides and the drum reads as a
      grey tube instead of as a machined shield.
    * Each primitive is its own MeshInstance3D with its own material. The core
      alone was well over a hundred draw calls standing in the middle of the
      one room the player crosses most often.

Four models replace all of that, at four draw calls, sharing the same 128x128
palette atlas as every other lp_ prop:

    lp_core_base     the dais: plinth lip, deck slab, machine footing and the
                     eight deck hatches
    lp_core_column   the machine: shield drums, bolted flanges, the eight-rib
                     cage, heat fins, status ring, head cap and collar
    lp_core_gantry   one maintenance catwalk; placed three times
    lp_core_plant    one coolant skid: pump, tank, riser, handwheel, junction
                     box; placed twice

WHAT DELIBERATELY STAYS PROCEDURAL
----------------------------------
    Anomalous Core      an emissive sphere, and nothing in this pipeline emits.
                        GameManager.gd looks the node up by that exact name.
    Containment Dome    likewise, and likewise looked up by name.
    the window          driven by shaders/ContainmentDome.gdshader.
    the cable trunks    their length is derived per-map from the soffit height.
    the plaque label    a Label3D carrying a translated string.
    every collider      unchanged, so the navmesh the Curator chase was tuned
                        against does not move.

NONE OF THESE FOUR IS IN MapModels.NON_BLOCKING, and none of them belongs
there. An earlier draft of this header claimed the opposite; it was never
true, and acting on it would have been wrong anyway. The dais hull IS the
navmesh island the chase was tuned around, the gantry deck is waist-high and
is meant to block rather than invite, a coolant skid is a 1.6 m obstacle, and
the jammed shutter is the thing that stops the player in the south bay.

ORIGINS -- READ BEFORE MOVING A NUMBER
--------------------------------------
All four models are floor-standing and every one of them has its origin on the
floor, centred on its own axis, per house style. They stack:

    lp_core_base     sits at the assembly origin.        Top of deck: y 0.240.
    lp_core_column   sits ON that deck, so it is placed at y 0.240 and its own
                     numbers start from zero there.      Top of cap ring: 2.795,
                     i.e. assembly y 3.035, which is where the procedural cable
                     trunks already leave for the ceiling. The COLLAR is 5 mm
                     higher again, 2.800 local / assembly 3.040, and that is the
                     bbox height Blender prints and what RULES max_y guards.
                     Both numbers are correct; this line used to credit 2.795 to
                     the collar, which sent one reader hunting a typo.
    lp_core_gantry   also sits on the deck at y 0.240. Local +Z points AWAY
                     from the core axis, so the placement yaw is 90 - the
                     compass angle -- and therefore THE WALKWAY RUNS ALONG
                     LOCAL Z, not along X. See the note over
                     build_core_gantry; authoring it along X once already
                     shipped three catwalks turned 90 degrees out of place.
    lp_core_plant    same deck, same +Z-is-outward convention.

THE ONE INVARIANT THIS FILE CAN BREAK
-------------------------------------
The eight cage ribs and the eight deck hatches sit on TAU*i/8 + PI/8, which
leaves the four cardinal sightlines through the cage open. The three gantries
sit on 45 / 135 / 225 degrees and the 315 degree quarter stays clear because
security camera 03 looks down the 317.2 degree ray from (13.6, 3.0, -12.6).

The two coolant skids flank that quarter and go at 279 and 351. Not 292.5 and
337.5, which is what an earlier draft of this header said and which now
survives only in the primitive fallback, and not 285 and 345 either. A skid
is 0.90 m wide AND 0.52 m deep at radius 1.20, so its inner corners subtend
51 degrees rather than the 41 the width alone suggests; 279 and 351 are the
outermost angles that leave the whole 305..325 window open, and outermost
matters because going further walks the skid into the 225 degree gantry.

Part.swing() carries a sign that is easy to get wrong, and a mirrored rib
ring would still export, still pass every count check, and still quietly shut
the sightline. So these angles are asserted, not eyeballed:

    python tools/lowpoly/check_core_layout.py

It checks reach, fouling and the sightline against the placement code in
AtriumProps.gd, in plain Python, with no Blender and no Godot. Run it after
touching any number in this file. It is the check that would have caught the
gantry.
"""

from __future__ import annotations

import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import blender_build as bb  # noqa: E402  -- Part, make_material, export_glb

OUT_DIR = bb.OUT_DIR


# =========================================================================
# lp_core_base -- 4.44 x 0.30 x 4.44 m dais, origin on the atrium floor
# =========================================================================
# The radii are the ones the primitive slab already used (lip 2.22, deck 2.05,
# hatch ring 1.72), because the rope barrier at 3.40 m, the floor signage and
# the three gantries are all surveyed against them.
#
# Two things are new and both are anti-shimmer. The deck is turned half a facet
# out of phase with the lip so their vertical faces never line up, and it is
# sunk 6 mm INTO the lip rather than stood on top of it -- the primitive pair
# met exactly at y 0.110 and that shared plane is one of the coplanar joints
# this whole pass exists to remove.
def build_core_base(material):
    p = bb.Part("lp_core_base")

    lip = p.prism((0.0, 0.0, 0.0), 2.220, 0.110, 12, "plinth",
                  cap_swatch="carcass_dark")
    p.bevel(p.facing(lip, "py"), 0.030, "carcass_side")

    deck = p.prism((0.0, 0.104, 0.0), 2.050, 0.136, 12, "carcass",
                   cap_swatch="carcass_side", phase=math.pi / 12.0)
    p.bevel(p.facing(deck, "py"), 0.026, "carcass_side")

    # Machine footing: the collar the column lands in, so the column does not
    # look pushed through a hole in a sheet of plate. Buried 8 mm in the deck.
    foot = p.prism((0.0, 0.232, 0.0), 0.880, 0.070, 12, "carcass_dark",
                   cap_swatch="brace", phase=math.pi / 12.0)
    p.bevel(p.facing(foot, "py"), 0.018, "brace")

    # Eight deck hatches on the TAU*i/8 + PI/8 spokes. Raised covers, not
    # painted rectangles: 8.5 mm of each is inside the deck and 11.5 mm stands
    # proud, so each one throws its own shadow line across the plate.
    for i in range(8):
        angle = math.tau * i / 8.0 + math.pi / 8.0
        mark = p.mark_verts()
        p.box((1.720, 0.2415, 0.0), (0.300, 0.020, 0.440), "carcass_dark",
              face_swatches={"py": "handle_dark"})
        # 1 mm proud of the cover it lies on -- the house anti-z-fight margin.
        p.panel((1.720, 0.2525, 0.0), (0.220, 0.340), "lock", "py")
        p.swing(mark, angle)

    return p, p.finish(material)


# =========================================================================
# lp_core_column -- 1.72 x 2.80 x 1.72 m, origin on the base deck
# =========================================================================
# Heights are carried over from the primitives so nothing that hangs off the
# core has to move: the sphere and the shader window sit at local y 1.20 in the
# open rib band, the shutter headers clear the upper drum, and the collar tops
# out at 2.795 where the cable trunks already leave.
#
# Every stacked part is buried 5-15 mm in the one below it. Read the y numbers
# as a chain, not as a stack of heights: the lower flange starts at 0.655 while
# the drum under it ends at 0.660, the upper drum starts at 1.730 while the
# flange ends at 1.735, and so on. Not one pair of faces is coplanar, which is
# the entire reason the core used to sparkle when the camera turned.
def build_core_column(material):
    p = bb.Part("lp_core_column")

    # ---- lower shield drum ----------------------------------------------
    p.prism((0.0, 0.0, 0.0), 0.660, 0.660, 10, "carcass",
            cap_swatch="carcass_dark")
    # Bolt band. One band instead of sixteen modelled bolt heads: sixteen boxes
    # cost 192 triangles and, 8 m away across the atrium, read as exactly the
    # same dark ring this costs 36 for.
    p.prism((0.0, 0.100, 0.0), 0.700, 0.090, 10, "handle_dark",
            cap_swatch="shadow", phase=math.pi / 10.0)

    lower_flange = p.prism((0.0, 0.655, 0.0), 0.820, 0.120, 12, "brace",
                           cap_swatch="carcass_side")
    p.bevel(p.facing(lower_flange, "py"), 0.018, "carcass_side")

    # ---- the cage --------------------------------------------------------
    # Eight ribs, INNER faces at radius 0.540. The sphere is r 0.330 and the
    # shader window r 0.500, so the cage clears the window by 40 mm and the
    # glow reads out between the ribs from every cardinal direction.
    for i in range(8):
        angle = math.tau * i / 8.0 + math.pi / 8.0
        mark = p.mark_verts()
        p.box((0.640, 1.200, 0.0), (0.200, 0.860, 0.140), "carcass_side",
              face_swatches={"px": "carcass", "nx": "shadow", "py": "brace"})
        p.swing(mark, angle)

    # Cage belts, deliberately at the very ends of the rib run: a belt across
    # the middle would cut the window in half from every angle at once.
    p.prism((0.0, 0.790, 0.0), 0.780, 0.050, 12, "handle_dark",
            cap_swatch="shadow")
    p.prism((0.0, 1.560, 0.0), 0.780, 0.050, 12, "handle_dark",
            cap_swatch="shadow")

    upper_flange = p.prism((0.0, 1.615, 0.0), 0.820, 0.120, 12, "brace",
                           cap_swatch="carcass_side")
    p.bevel(p.facing(upper_flange, "py"), 0.018, "carcass_side")

    # ---- upper shield drum ----------------------------------------------
    p.prism((0.0, 1.730, 0.0), 0.660, 0.640, 10, "carcass",
            cap_swatch="carcass_dark")

    # Heat fins. Twelve, not twenty-four: at 0.035 m thick a fin is one pixel
    # wide from the entrance and the pair merges, so half of them were paying
    # for a moire pattern.
    for i in range(12):
        angle = math.tau * i / 12.0
        mark = p.mark_verts()
        p.box((0.695, 1.980, 0.0), (0.130, 0.320, 0.035), "carcass_side")
        p.swing(mark, angle)

    # ---- status ring -----------------------------------------------------
    # A solid band, so the cells have something to be mounted ON. The primitive
    # version floated its cells on a torus and they read as loose beads.
    ring = p.prism((0.0, 2.200, 0.0), 0.840, 0.110, 12, "carcass_dark",
                   cap_swatch="brace")
    p.bevel(p.facing(ring, "py"), 0.016, "brace")

    # Two dead cells out of eight, same as the primitives had: a status board
    # with every lamp identical reads as decoration, not as a readout.
    for i in range(8):
        angle = math.tau * i / 8.0
        swatch = "glass_dead" if i in (6, 7) else (
            "lock" if i % 2 else "steel_bright")
        mark = p.mark_verts()
        p.box((0.845, 2.255, 0.0), (0.060, 0.100, 0.160), swatch)
        p.swing(mark, angle)

    # ---- head ------------------------------------------------------------
    p.prism((0.0, 2.355, 0.0), 0.660, 0.260, 10, "carcass_side",
            top_radius=0.360, cap_swatch="top_cap")
    collar = p.prism((0.0, 2.600, 0.0), 0.400, 0.200, 8, "carcass_dark",
                     cap_swatch="brace")
    p.bevel(p.facing(collar, "py"), 0.020, "brace")
    # Cap ring: the last horizontal on the silhouette, and what the procedural
    # cable trunks appear to leave from.
    p.prism((0.0, 2.740, 0.0), 0.440, 0.055, 8, "handle_dark",
            cap_swatch="shadow", phase=math.pi / 8.0)

    return p, p.finish(material)


# =========================================================================
# lp_core_gantry -- 0.95 x 2.00 x 1.46 m catwalk, outward face is +Z
# =========================================================================
# One unit, placed three times at 45 / 135 / 225 degrees. Origin on the base
# deck, THE WALKWAY RUNNING ALONG LOCAL Z, which is the axis Models.place
# sends outward.
#
# THAT AXIS IS THE WHOLE NOTE. This model shipped once with the deck along X.
# It exported, it passed every rule in RULES below, it imported, and it moved
# the MeshInstance3D count -- and it was wrong, because the same yaw turns a
# deck authored along X into a 1.44 m TANGENTIAL balcony. Placed, it spanned
# r 0.93 .. 1.79: 190 mm short of the rib cage it is supposed to be bolted to,
# 260 mm short of the slab edge, railed on the outboard side and open to a
# 0.95 m drop on the side facing the core, and clipping the south shutter
# rails by 105 mm. Three catwalks floating in the middle of the dais.
#
# The primitive fallback in AtriumProps._build_core_gantries is the reference
# and it is written against _radial_box, whose local +X is the outward one. Its
# Vector3(1.44, 0.10, 0.86) therefore reads 1.44 m RADIAL by 0.86 m tangential,
# so this model is 0.860 in X and 1.440 in Z. Same object, opposite convention.
#
# Deck spans r 0.640 .. 2.080 once placed. The inner end bites 100 mm into the
# cage (rib outer face r 0.740) so the walkway lands ON the machine instead of
# stopping in mid-air, and the outer end oversails the deck slab (r 2.050) by
# 30 mm without reaching the plinth lip at 2.220.
#
# Legs stand at the outer end ONLY, exactly as the fallback has them: a
# maintenance stage over a hot vessel is cantilevered off the vessel and
# propped at the far end, and a leg further in would land on the machine
# footing, which is r 0.880 and stands 60 mm proud of the deck.
#
# Guard rail tops out at local 1.995, i.e. assembly 2.235 -- under the 2.62
# shutter headers, so the two never fight. There is no rail and no toe board
# on the inner end, because that end is inside the cage.
def build_core_gantry(material):
    p = bb.Part("lp_core_gantry")

    # Kicked feet at the outer end, so the legs are not welded to the plate.
    for x in (-0.320, 0.320):
        p.taper((x, 0.0, 0.560), (0.240, 0.240), (0.190, 0.190), 0.050,
                "plinth", cap_top=False, cap_bottom=False)
    for x in (-0.320, 0.320):
        p.box((x, 0.470, 0.560), (0.150, 0.940, 0.150), "brace",
              face_swatches={"py": "shadow"})

    deck_mark = p.mark_faces()
    p.box((0.0, 0.970, 0.0), (0.860, 0.100, 1.440), "carcass_side",
          face_swatches={"py": "brace", "ny": "shadow"})
    deck = p.new_faces(deck_mark)
    p.bevel(p.facing(deck, "py"), 0.020, "brace")
    # Tread wear, 1 mm proud of the walking surface. A "py" panel is sized
    # (X, Z), so this is 0.700 across the walkway by 1.300 along it -- the two
    # numbers swap with the deck, and forgetting to swap them is how you get a
    # wear patch hanging over both edges.
    p.panel((0.0, 1.0210, 0.0), (0.700, 1.300), "grime", "py")

    # Toe boards on the three open edges: both long sides and the outer end.
    # Each is 10 mm down inside the deck and 15 mm proud of the face it guards.
    for x in (-0.445, 0.445):
        p.box((x, 1.080, 0.0), (0.060, 0.140, 1.440), "carcass_dark",
              face_swatches={"px": "lock", "nx": "lock"})
    p.box((0.0, 1.080, 0.705), (0.860, 0.140, 0.060), "carcass_dark",
          face_swatches={"pz": "lock"})

    # Four posts, not two: one pair at the outer end and one pair where the
    # deck meets the machine, so a 1.44 m handrail is not a plank on a stick.
    # Buried 10 mm in the deck, like everything else that stands on something.
    for x in (-0.380, 0.380):
        for z in (-0.560, 0.660):
            p.box((x, 1.495, z), (0.090, 0.970, 0.090), "brace")

    # Handrail and knee rail down both long sides, and across the outer end.
    for x in (-0.400, 0.400):
        p.box((x, 1.960, 0.0), (0.080, 0.070, 1.400), "handle_dark")
        p.box((x, 1.520, 0.0), (0.070, 0.060, 1.400), "handle_dark")
    p.box((0.0, 1.960, 0.660), (0.850, 0.070, 0.090), "handle_dark")
    p.box((0.0, 1.520, 0.660), (0.850, 0.060, 0.070), "handle_dark")

    return p, p.finish(material)


# =========================================================================
# lp_core_plant -- 0.90 x 1.62 x 0.52 m coolant skid, service face is +Z
# =========================================================================
# Placed twice, at 279 and 351 degrees. NOT the 292.5 and 337.5 this comment
# claimed until the layout checker was written, and not 285 and 345 either.
# The skid is 0.90 m wide AND 0.52 m deep, so its inner corners subtend 51
# degrees, not the 41 the width alone suggests -- both earlier pairs closed the
# 305..325 window that security camera 03 looks through on the 317.2 degree ray,
# and a 1.6 m tall skid parked in it puts a tank where the core is supposed to
# be. 279 and 351 are also the OUTERMOST angles available: past them the skid
# walks into the 225 degree gantry, and there is only 21 mm to give.
#
# See the sector note in the header, and tools/lowpoly/check_core_layout.py --
# it solves both bounds instead of trusting a comment, which is precisely how
# this line was caught being wrong.
#
# This is what the rejected primitive service rig was trying to be. Same parts
# -- pump, tank, riser, handwheel, junction box -- but as one object standing on
# one skid, instead of thirty loose cylinders scattered around the plinth at
# radii that never touched anything.
def build_core_plant(material):
    p = bb.Part("lp_core_plant")

    skid_mark = p.mark_faces()
    p.box((0.0, 0.050, 0.0), (0.900, 0.100, 0.520), "plinth",
          face_swatches={"py": "carcass_dark"})
    skid = p.new_faces(skid_mark)
    p.bevel(p.facing(skid, "py"), 0.016, "carcass_side")

    # Pump body and motor, both sunk into the thing below them.
    p.prism((-0.230, 0.092, 0.0), 0.185, 0.400, 10, "carcass",
            cap_swatch="carcass_dark")
    p.prism((-0.230, 0.470, 0.0), 0.130, 0.230, 8, "handle_dark",
            cap_swatch="shadow")
    # Handwheel and hub. Horizontal on the motor head: a vertical wheel would
    # need a rotation this toolchain only has about X, and a wheel lying flat
    # on a pump is what an isolation valve looks like anyway.
    p.prism((-0.230, 0.690, 0.0), 0.150, 0.030, 10, "tag", cap_swatch="rust")
    p.prism((-0.230, 0.712, 0.0), 0.048, 0.050, 8, "steel_bright",
            cap_swatch="handle")

    # Coolant tank, its strap band, and the riser leaving the top.
    p.prism((0.200, 0.090, 0.0), 0.220, 0.840, 10, "carcass_side",
            cap_swatch="brace")
    p.prism((0.200, 0.520, 0.0), 0.235, 0.060, 10, "handle_dark",
            cap_swatch="shadow", phase=math.pi / 10.0)
    p.prism((0.200, 0.900, 0.0), 0.055, 0.720, 8, "handle_dark",
            cap_swatch="shadow")
    # Elbow turning the riser in towards the core, i.e. towards -Z.
    p.box((0.200, 1.585, -0.110), (0.100, 0.100, 0.280), "handle_dark")

    # Junction box, bolted to the pump flank so it is not a floating cube.
    p.box((-0.330, 0.560, 0.170), (0.220, 0.300, 0.140), "carcass_dark",
          face_swatches={"pz": "door_dark"})
    p.panel((-0.330, 0.640, 0.2405), (0.150, 0.090), "label", "pz")
    p.panel((-0.330, 0.520, 0.2405), (0.110, 0.050), "tag", "pz")

    # Hazard edge on both long faces of the skid, 0.5 mm proud.
    p.panel((0.0, 0.050, -0.2605), (0.820, 0.060), "lock", "nz")
    p.panel((0.0, 0.050, 0.2605), (0.820, 0.060), "lock", "pz")
    p.panel((0.200, 0.9310, 0.0), (0.300, 0.300), "grime", "py")

    return p, p.finish(material)


BUILDERS = (build_core_base, build_core_column, build_core_gantry,
            build_core_plant)

BUDGET = {
    "lp_core_base": 600,
    "lp_core_column": 1200,
    "lp_core_gantry": 400,
    "lp_core_plant": 500,
}

# Per-model house-style rules, in metres.
RULES = {
    "lp_core_base": {"floor_y": 0.0, "centre_x": True, "centre_z": True,
                     "max_y": 0.320},
    # Must not reach the 3.39 m soffit once stood on the 0.24 deck at y 0.16.
    "lp_core_column": {"floor_y": 0.0, "centre_x": True, "centre_z": True,
                       "max_y": 2.850},
    # No centre_z on purpose. Z is the RADIAL axis for this model and the outer
    # toe board stands 15 mm proud of the deck end, so the bbox runs
    # -0.720 .. +0.735. centre_x is the one that still has to hold: it is what
    # keeps the walkway centred on its own radius.
    "lp_core_gantry": {"floor_y": 0.0, "centre_x": True, "max_y": 2.050},
    "lp_core_plant": {"floor_y": 0.0, "centre_x": True, "centre_z": True,
                      "max_y": 1.700},
}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not os.path.isdir(OUT_DIR):
        os.makedirs(OUT_DIR)

    material = bb.make_material()
    print("BLENDER", bpy.app.version_string)
    print("SWATCHES", len(bb.SWATCH_NAMES))
    print("OUT_DIR", OUT_DIR)

    rows = []
    failures = []
    for builder in BUILDERS:
        part, obj = builder(material)
        path = os.path.join(OUT_DIR, part.name + ".glb")
        bb.export_glb(obj, path)

        (lo, hi) = part.bounds
        size = (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
        nbytes = os.path.getsize(path) if os.path.exists(path) else 0
        rule = RULES[part.name]

        if "floor_y" in rule and abs(lo[1] - rule["floor_y"]) > 1e-4:
            failures.append("%s: floor at y=%.4f, must be %.4f"
                            % (part.name, lo[1], rule["floor_y"]))
        if rule.get("centre_x") and abs(lo[0] + hi[0]) > 2e-3:
            failures.append("%s: not centred in X (%.4f .. %.4f)"
                            % (part.name, lo[0], hi[0]))
        if rule.get("centre_z") and abs(lo[2] + hi[2]) > 2e-3:
            failures.append("%s: not centred in Z (%.4f .. %.4f)"
                            % (part.name, lo[2], hi[2]))
        if "max_y" in rule and hi[1] > rule["max_y"] + 1e-4:
            failures.append("%s: reaches y=%.4f, over the %.3f ceiling"
                            % (part.name, hi[1], rule["max_y"]))
        if part.tris > BUDGET[part.name]:
            failures.append("%s: %d tris, over the %d budget"
                            % (part.name, part.tris, BUDGET[part.name]))
        if nbytes == 0:
            failures.append("%s: export produced no file" % part.name)

        rows.append((part.name, lo, hi, size, part.tris, part.quads, nbytes))
        bpy.data.objects.remove(obj, do_unlink=True)

    print("")
    print("%-18s %-26s %6s %6s %9s"
          % ("model", "bbox W x H x D (m)", "tris", "faces", "bytes"))
    print("-" * 72)
    for name, lo, hi, size, tris, quads, nbytes in rows:
        print("%-18s %-26s %6d %6d %9d"
              % (name, "%.3f x %.3f x %.3f" % size, tris, quads, nbytes))
        print("%-18s x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f"
              % ("", lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    print("")

    if failures:
        for line in failures:
            print("FAIL", line)
        raise SystemExit(
            "blender_core: %d house-style violation(s)" % len(failures))

    print("BUILD_OK", len(rows), "models")


if __name__ == "__main__":
    main()
