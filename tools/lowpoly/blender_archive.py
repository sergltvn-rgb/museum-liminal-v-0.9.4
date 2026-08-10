"""Blender-authored low-poly archive furniture for museum-liminal.

RUN IT LIKE THIS (no GUI, nothing to click):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/lowpoly/blender_archive.py

And then, without exception:

    Godot_v4.7-stable_win64_console.exe --path . --headless --import

Without the import step ResourceLoader.exists() answers false,
MapModels.place() returns null, ArchiveProps quietly draws the primitive
fallback instead -- and every test still passes. The only proof a model
actually landed is the MeshInstance3D count in game/test_map_verification.gd
MOVING, and for this batch it must move DOWN.

WHY THIS FILE EXISTS
--------------------
ArchiveProps._stack_carriage is the densest primitive cluster left in the
building. One carriage shell is twenty-one MeshInstance3D nodes -- plinth, two
end panels, four uprights, four rails, four seams, top cap, drive wheel, axle,
handwheel, hub, grip -- and build_rolling_stacks places five of them. A
hundred and five draw calls for a rank of grey cabinets standing in the one
room whose whole horror is the dark slot between two of them.

The shell is also the part that is IDENTICAL on all five carriages, which is
what makes it a model rather than a rewrite: one .glb, placed five times.

The file carries a second model on the same terms. AtriumProps.
build_rotunda_bench is twenty-four MeshInstance3D nodes and build_atrium
places it four times on the rotunda diagonals; nothing about a bench differs
between the four, so it is one .glb placed four times. The rationale for that
one sits directly above build_rotunda_bench below -- keep each model's
reasoning next to its numbers.

The third model is the lobby's own front desk. LobbyProps.
build_reception_counter is thirty-one MeshInstance3D nodes and fifteen of them
are the L-shaped joinery: toe kick, carcass, staff worktop, brass nosing, the
fascia with its three fields and two stiles, two end panels and the entire
return wing. It is built once, it never varies, and it is the first object the
player sees through the street door -- which is the one place in the building
where a chamfer and a genuinely recessed panel field earn their .glb. Its
reasoning sits directly above build_lobby_counter.

WHAT DELIBERATELY STAYS PROCEDURAL
----------------------------------
    the shelves and box files    _stack_shelves, and only on the two carriages
                                 either side of the open gap. Nobody can see
                                 into the other three, so baking shelves into
                                 the shell would pay for nine meshes x 5 to
                                 light three interiors that are sealed.
    the outer skin               index 0 and index bays-1 only. Eight parts on
                                 two carriages; in the model they would appear
                                 on all five and close the rank in on itself.
    the index holder and card    ABSENT ON CARRIAGE 1 ON PURPOSE. That missing
                                 card is authored storytelling -- the one
                                 carriage nobody wrote a label for is the one
                                 the gap opens onto. Baked into the shell it
                                 would appear on all five and the detail dies.
    the collider                 unchanged: the surveyed 0.94 x 2.20 x 3.00 box
                                 _stack_carriage already builds. See COLLISION.

ORIENTATION -- READ BEFORE MOVING A NUMBER
------------------------------------------
Origin on the floor, centred in X, per house style. Forward is -Z, so THE
OPERATING END -- the one carrying the handwheel, the drive wheel and the index
card -- IS AUTHORED AT LOCAL -Z and the call site places the carriage with
yaw 180, exactly as AtriumProps.build_reception_desk does with
lp_reception_counter.

That 180 is the whole note. In ArchiveProps the operating end faces +Z, so
every z in this file is the NEGATED source number and so is every x:

    model_x = -world_x        model_z = -world_z

The only X-asymmetric part is the handwheel grip, authored at x -0.150 so that
after the yaw it lands back on the +0.150 the primitives had.

THE BBOX IS NOT CENTRED IN Z AND THAT IS CORRECT
------------------------------------------------
The handwheel assembly stands proud of the operating end: the grip reaches
z -1.6225 while the far end stops at +1.5175. Depth is therefore 3.140, not
the 3.000 the carcass measures, which is also why build_rolling_stacks quotes
a 3.19 m block depth. RULES below drops centre_z for this model, the same
exemption lp_core_gantry carries, and keeps centre_x, which is the one that
has to hold: it is what keeps the carriage centred on its own rail.

COLLISION -- lp_stack_carriage BELONGS IN MapModels.NON_BLOCKING
----------------------------------------------------------------
This is the lp_door_leaf case, not the CCTV case. The body that stops the
player is a single box built next to the model in _stack_carriage, surveyed at
0.94 x 2.20 x 3.00 and described in that code as one clean box for navigation.
A generated hull would be a SECOND collider wrapping the same volume, 140 mm
deeper, and those 140 mm are the handwheels sticking into the operating aisle
that _bake_navigation() reads. Five extra static bodies, a narrower aisle, and
the StaticBody3D count moves off 547 for nothing.

PALETTE
-------
The atlas has no entry for the archive's own darkened tones, so each part uses
the NEAREST swatch to the colour the primitive carried:

    _STEEL_DARK   tone(STEEL_DARK, -0.30) = 0.112 0.133 0.147 -> carcass_dark
    _STACK_FACE   tone(STEEL,      -0.30) = 0.280 0.322 0.350 -> hinge
    _STACK_TRIM             0.410 0.435 0.430                 -> steel_bright
    _STACK_LABEL            0.650 0.620 0.500                 -> stone_pale

ANTI-COPLANARITY -- THREE JOINTS THAT MOVED
-------------------------------------------
The primitives met on shared planes in three places, which is the shimmer this
pipeline exists to remove. All three are fixed here and the fixes are the only
deliberate departures from the source numbers:

  * the end panel used to start exactly at the plinth top (0.120) and stop
    exactly at the cap bottom (2.140). It now runs 0.110 .. 2.140 and the cap
    starts at 2.132, so both ends are buried.
  * the end panel was as wide as the plinth (0.940), so their side faces were
    coplanar over the 10 mm they share in Y. The panel is now 0.920 and the
    10 mm reveal reads as a shadow line.
  * the rails and the uprights were at the same depth, so their front faces
    were coplanar where they cross. The rails now sit 2 mm shallower.

Every pitch() in this file rotates a part about ITS OWN CENTRE, so the sign of
the rotation cannot matter: a prism is symmetric about its mid-plane and comes
out as the same cylinder whichever way it is spun.
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
# lp_stack_carriage -- 0.94 x 2.20 x 3.14 m, operating end faces -Z
# =========================================================================
# Placed five times by ArchiveProps.build_rolling_stacks, at yaw 180, on the
# STACK_PITCH 0.98 rail run. Carcass is 0.940 x 2.200 x 3.000 -- the same
# numbers as STACK_CARRIAGE_W / _H / _L and as the collider -- and the extra
# 140 mm of depth is handwheel, which no carcass measurement includes.
def build_stack_carriage(material):
    p = bb.Part("lp_stack_carriage")

    # ---- plinth ----------------------------------------------------------
    # Full 3.000 m of the carcass footprint. Chamfered on top because that is
    # the edge a torch rakes along when the player walks the aisle.
    plinth = p.box((0.0, 0.060, 0.0), (0.940, 0.120, 3.000), "carcass_dark",
                   face_swatches={"py": "plinth", "ny": "shadow"})
    p.bevel(p.facing(plinth, "py"), 0.016, "carcass_side")

    # ---- top cap ---------------------------------------------------------
    # Starts at 2.132, i.e. 8 mm BELOW the top of the end panels, and tops out
    # at 2.200 = STACK_CARRIAGE_H exactly.
    cap = p.box((0.0, 2.166, 0.0), (0.940, 0.068, 3.000), "carcass_dark",
                face_swatches={"py": "top_cap"})
    p.bevel(p.facing(cap, "py"), 0.014, "carcass_side")
    # Dust, on top where nobody dusts. 0.5 mm proud of the cap.
    p.panel((0.0, 2.2005, 0.220), (0.600, 1.900), "grime", "py")

    # ---- the two ends ----------------------------------------------------
    # e is the END SIGN in model space: -1 is the operating end. Both ends
    # carry the same panel, uprights, rails and seams; only the operating end
    # gets the running gear below.
    for e in (-1.0, 1.0):
        face_z = e * 1.505

        # End panel. 0.920 wide against the plinth's 0.940: see the
        # anti-coplanarity note in the header.
        p.box((0.0, 1.125, e * 1.480), (0.920, 2.030, 0.040), "hinge")

        # Corner uprights, 7.5 mm of each buried in the panel.
        for x in (-0.400, 0.400):
            p.box((x, 1.130, face_z), (0.045, 1.880, 0.025), "steel_bright")

        # Head and foot rails, 2 mm shallower than the uprights they cross.
        for y in (0.220, 2.040):
            p.box((0.0, y, e * 1.503), (0.820, 0.045, 0.025), "steel_bright")

        # Two shallow seams: the panel is a pressed sheet, not a slab.
        for y in (0.760, 1.300):
            p.box((0.0, y, e * 1.5065), (0.740, 0.018, 0.018), "carcass_dark")

    # ---- running gear, operating end only --------------------------------
    # Each of these is a prism authored along Y and then pitched 90 degrees
    # about its own centre, which lands its axis on Z without the sign of the
    # rotation mattering. Building them about a remote pivot would move the
    # part as well as turn it, which is the mistake this pattern avoids.
    for centre, radius, length, sides, side_swatch, cap_swatch in (
            # drive wheel and its axle, half sunk in the plinth
            ((0.0, 0.130, -1.280), 0.120, 0.075, 10, "steel_bright",
             "handle_dark"),
            ((0.0, 0.130, -1.330), 0.035, 0.100, 8, "carcass_dark", "shadow"),
            # handwheel, its hub, and the grip that turns it
            ((0.0, 1.150, -1.535), 0.190, 0.050, 10, "steel_bright",
             "handle_dark"),
            ((0.0, 1.150, -1.545), 0.048, 0.100, 8, "handle_dark", "handle"),
            ((-0.150, 1.150, -1.585), 0.022, 0.075, 8, "stone_pale",
             "label")):
        mark = p.mark_verts()
        p.prism((centre[0], centre[1] - length / 2.0, centre[2]),
                radius, length, sides, side_swatch, cap_swatch=cap_swatch)
        p.pitch(mark, centre, 90.0)

    return p, p.finish(material)


# =========================================================================
# lp_rotunda_bench -- 3.34 x 1.03 x 0.69 m, the SEAT faces -Z
# =========================================================================
# The four-seater on each rotunda diagonal. AtriumProps.build_atrium places it
# at r 8.4 on 45/135/225/315 with yaw -(angle + 90), which turns the long axis
# onto the tangent and points the seat at the containment core.
#
# ORIENTATION: no 180 flip here, unlike lp_stack_carriage. The source already
# authors +x as the length and +z as the BACK, so the seat already looks down
# -Z and model space equals the GDScript local space number for number. The
# call site keeps passing facing_deg straight through.
#
# NOT CENTRED IN Z, ON PURPOSE: the back rail and the back posts overhang to
# +0.3525 while the brass foot plates stop at -0.340. The collider
# (3.40 x 0.47 x 0.70 round the seat volume) stays where it was, centred on
# z 0, because that is the volume a body has to be kept out of -- the back
# rail at 1.03 m is over head height for the nav agent and never was solid.
# So RULES drops centre_z and keeps centre_x, which is what holds the bench on
# its own radius.
#
# COLLISION: lp_rotunda_bench belongs in MapModels.NON_BLOCKING for the
# lp_stack_carriage reason. build_rotunda_bench keeps building its one surveyed
# box; a generated hull would wrap the arms, the back and the foot plates as
# well and hand the bake four extra static bodies on the main circulation ring.
#
# PALETTE: the bench is authored in three atrium tones and each maps to its
# nearest atlas swatch:
#
#     WOOD   tone(Pal.WOOD,  -0.52) = 0.106 0.072 0.041 -> wood_dark
#     IRON                    0.062 0.066 0.070         -> brace
#     BRASS  tone(Pal.BRASS, -0.32) = 0.340 0.258 0.116 -> lock
#
# The seat boards and the arms take the lighter `wood` on their TOP face only:
# those are the two surfaces a museum bench is polished by, and it is the one
# piece of tonal information the flat primitives could not carry.
#
# FOUR NUMBERS MOVED, ALL FOR THE SAME REASON AS IN THE CARRIAGE
# --------------------------------------------------------------
#   * back post 0.080 -> 0.076 wide. It shared both side faces with the frame
#     rail it lands on (both spanned x 1.440 .. 1.520) over the 20 mm they
#     overlap in Y. Now the post is 2 mm inside the rail on each side.
#   * back post top 1.030 -> 1.022. It ended in exactly the plane of the back
#     rail top, 76 x 70 mm of coplanar cap right at eye level. Now it is
#     buried 8 mm under the rail.
#   * legs start at y 0.020 instead of 0.000. Their bottom face used to be
#     coplanar with the brass foot plate's bottom face AND with the floor --
#     three surfaces in one plane. The leg now stands 4 mm inside the plate.
#   * stretcher moved from z 0.010 to 0.220 and lengthened 2.860 -> 2.900.
#     At the source numbers it touched NOTHING: its ends stopped 5 mm short of
#     the legs in x, and at z 0.010 it hung in the 0.42 m void between each
#     end frame's two legs. On the rear leg line it does what a stretcher does,
#     15 mm of each end buried in a leg, and the front legs hide it.
def build_rotunda_bench(material):
    p = bb.Part("lp_rotunda_bench")

    # ---- seat: five boards on a 0.13 pitch, 2.5 cm of daylight between ----
    # The chamfer is the point of modelling this at all: a bare 90 degree
    # board edge at knee height is the tell that a bench is six boxes.
    for i in range(5):
        seat = p.box((0.0, 0.455, -0.26 + 0.13 * float(i)),
                     (3.28, 0.05, 0.105), "wood_dark",
                     face_swatches={"py": "wood"})
        p.bevel(p.facing(seat, "py"), 0.008, "wood")

    # ---- back: three boards stepping outward as they rise ----------------
    # Each leans 5.5 degrees about ITS OWN CENTRE, so the number is the same
    # -5.5 the GDScript sets on rotation_degrees.x and the sign convention is
    # the one pitch() documents: positive tips the top towards +Z.
    for i in range(3):
        centre = (0.0, 0.63 + 0.16 * float(i), 0.270 + 0.015 * float(i))
        mark = p.mark_verts()
        p.box(centre, (3.28, 0.13, 0.045), "wood_dark")
        p.pitch(mark, centre, -5.5)

    # ---- the two cast-iron end frames ------------------------------------
    for side in (-1.0, 1.0):
        x = side * 1.48
        # Two legs and the rail they carry the seat on.
        p.box((x, 0.225, -0.20), (0.09, 0.41, 0.10), "brace")
        p.box((x, 0.225, 0.22), (0.09, 0.41, 0.10), "brace")
        p.box((x, 0.415, 0.01), (0.08, 0.07, 0.64), "brace")
        # Back post: narrowed and shortened, see the header of this block.
        p.box((x, 0.726, 0.315), (0.076, 0.592, 0.07), "brace")
        # Timber arm on an iron bracket.
        arm = p.box((side * 1.46, 0.70, -0.01), (0.07, 0.06, 0.60),
                    "wood_dark", face_swatches={"py": "wood"})
        p.bevel(p.facing(arm, "py"), 0.006, "wood")
        p.box((side * 1.46, 0.57, -0.25), (0.06, 0.30, 0.06), "brace")
        # Brass foot plate: the museum bolts its benches to the floor.
        p.box((x, 0.012, 0.0), (0.17, 0.024, 0.68), "lock")

    # Stretcher on the rear leg line, and the back rail.
    p.box((0.0, 0.155, 0.220), (2.900, 0.06, 0.06), "brace")
    p.box((0.0, 1.000, 0.315), (3.04, 0.06, 0.075), "brace")

    return p, p.finish(material)


# =========================================================================
# lp_lobby_counter -- 4.84 x 1.07 x 3.24 m, the PUBLIC face is +Z
# =========================================================================
# The L-shaped reception desk in the entrance hall, placed once by
# LobbyProps.build_reception_counter at the room origin with no yaw.
#
# ORIENTATION: no flip, and no negated numbers. LobbyProps already authors the
# visitor on +Z (fascia at z 0.475, the rope queue out at z 3.1) and the staff
# on -Z, so model space equals that local space number for number. The long run
# is x, the return wing goes back along -z off the west end. The call site
# passes no rotation at all.
#
# THE BBOX IS NOT CENTRED IN Z, AND THE WING IS WHY
# -------------------------------------------------
# The main run measures 0.92 deep and the wing carries the envelope out to
# z -2.660, while the brass nosing stops at +0.575. So depth reads 3.235 and
# width reads 4.840 -- the nosing, not the carcass: it is run + 0.240 wide and
# so overhangs the end panels at +-2.360 by 60 mm on each side. That is the
# figure to quote for this model, and
# RULES drops centre_z, the lp_stack_carriage / lp_rotunda_bench exemption.
# centre_x DOES hold and matters: the desk is centred on the room's x 0 axis,
# where the sign rods above it and the door sightline both are.
#
# WHAT DELIBERATELY STAYS PROCEDURAL -- THE TWO STONE SLABS
# ---------------------------------------------------------
# Counter Ledge (4.84 x 0.08 x 1.10) and Counter Wing Ledge keep being built in
# GDScript, and this is the one decision in the batch that costs meshes on
# purpose. Both carry MaterialLib's "travertine" pack -- a 2K colour, normal,
# roughness and AO set, deliberately small-scaled so the seams show on a 1.1 m
# strip -- and they are the surfaces the visitor leans on, 1.10 m up and closest
# to the camera of anything in the room. Baked into this model they would become
# one flat 128 px atlas swatch with no normal map at all: a visible downgrade
# exactly where the player looks. The joinery under them has no pack and loses
# nothing. Same reasoning for the desk clutter and the hanging sign above.
#
# COLLISION -- lp_lobby_counter BELONGS IN MapModels.NON_BLOCKING
# --------------------------------------------------------------
# A generated convex hull would wrap the L into ONE solid block: it would fill
# the staff enclosure the wing exists to close, seal the 0.27 m gap under the
# ledge, and swallow the kick reveal. The two boxes the carcasses used to carry
# (4.60 x 0.62 x 0.92 on the run, 0.92 x 0.62 x 2.30 on the wing) are what a
# body has to be kept out of, so build_reception_counter now builds exactly
# those two as bare StaticBody3D nodes next to the model -- and both stone
# ledges keep their own colliders, untouched. Net static bodies: unchanged.
#
# PALETTE
# -------
#     WOOD        0.220 0.150 0.085  -> wood        (exact atlas match)
#     WOOD_LIGHT  0.360 0.250 0.135  -> wood_light  (nearest; atlas tone is
#                                      less saturated, which reads as the
#                                      lighter oak the source intended)
#     STONE_DARK  0.400 0.380 0.320  -> plinth      (the kick, in permanent
#                                      shadow; its "concrete" pack is the one
#                                      texture this model gives up, and 12 cm
#                                      of recessed shadow line never showed it)
#     BRASS       0.500 0.380 0.170  -> lock
#
# ANTI-COPLANARITY -- SEVEN JOINTS MOVED, TWO OF THEM REAL BUGS
# ------------------------------------------------------------
# The first two were not shimmer risks, they were wrong geometry:
#
#   * THE FASCIA STILES STOOD INSIDE THE FIELDS. The three fields sit at
#     x -1.5 / 0 / 1.5 and are 1.22 wide, so the gaps between them are centred
#     on x +-0.75. The two stiles were written at x -1.00 and +0.50 -- both
#     INSIDE a field, not in a gap -- and at the same z 0.495..0.515, so each
#     stile was a box interpenetrating a box with a coplanar front face, in the
#     dead centre of the view from the street door. There are no separate stiles
#     in this model: the fascia is three panels and each panel's own 85 mm frame
#     IS the stile, which is how the joinery the comment describes is built.
#   * THE FIELDS WERE PROUD, NOT RECESSED. Field front at z 0.515 against a
#     fascia front at 0.500: 15 mm of overlay, where the source comment promises
#     "three recessed fields". Here inset() carves them 12 mm INTO the panel.
#
# The other five are ordinary shared planes:
#
#   * kick top 0.120 was exactly carcass bottom 0.120. Kick is now 0.128 tall,
#     so 8 mm of it is buried in the carcass.
#   * fascia bottom 0.130 left a 10 mm slot down to the kick top. It now starts
#     at 0.126 and overlaps the kick by 2 mm.
#   * end panels were as deep as the carcass (0.920), sharing an edge line at
#     z +-0.460. They are 0.900 now and the 10 mm reveal reads as a shadow.
#   * nosing top 1.020 was exactly the stone ledge's underside. Raised 2 mm so
#     it dies inside the slab it hangs off.
#   * the wing fascia's inner face sat in the same plane as the west end panel's
#     at x -2.300. Widened 0.050 -> 0.052 so it ends 2 mm inside it.
def build_lobby_counter(material):
    p = bb.Part("lp_lobby_counter")
    run, depth = 4.600, 0.920

    # ---- main run: kick, carcass, staff worktop --------------------------
    p.box((0.0, 0.064, 0.0), (run - 0.120, 0.128, depth - 0.120), "plinth",
          face_swatches={"ny": "shadow"})
    p.box((0.0, 0.430, 0.0), (run, 0.620, depth), "wood")
    # Worktop at 0.75: chamfered, because this is the edge the clerk's wrists
    # rest on and the one lit surface inside the desk's own shadow.
    top = p.box((0.0, 0.730, -0.170), (run - 0.100, 0.040, depth - 0.420),
                "wood_light")
    p.bevel(p.facing(top, "py"), 0.006, "wood_light")

    # ---- brass nosing under the visitor ledge ---------------------------
    nose = p.box((0.0, 0.992, 0.550), (run + 0.240, 0.060, 0.050), "lock")
    p.bevel(p.facing(nose, "pz"), 0.005, "handle")

    # ---- fascia: three panels, each with a real recessed field ----------
    # 1.530 apiece, spanning -2.295..2.295 -- 5 mm inside the carcass ends, so
    # no shared edge line with the end panels either.
    for i in range(3):
        fx = -1.530 + 1.530 * float(i)
        panel = p.box((fx, 0.598, 0.4775), (1.530, 0.944, 0.045), "wood")
        p.inset(p.facing(panel, "pz"), 0.085, -0.012, "wood", "wood_light")

    # ---- end panels, chamfered on the corner the visitor walks past -----
    for side in (-1.0, 1.0):
        end = p.box((side * (run * 0.5 + 0.030), 0.598, 0.0),
                    (0.060, 0.944, depth - 0.020), "wood_light")
        p.bevel(p.facing(end, "px" if side > 0.0 else "nx"), 0.006,
                "wood_light")

    # ---- return wing, closing the staff enclosure along -z --------------
    wing_len = 2.300
    wx = -(run * 0.5) + 0.460
    wz = -(depth * 0.5) - wing_len * 0.5 + 0.100
    p.box((wx, 0.064, wz), (depth - 0.120, 0.128, wing_len - 0.120), "plinth",
          face_swatches={"ny": "shadow"})
    p.box((wx, 0.430, wz), (depth, 0.620, wing_len), "wood")
    wing_face = p.box((wx - depth * 0.5 - 0.026, 0.598, wz),
                      (0.052, 0.944, wing_len), "wood_light")
    p.bevel(p.facing(wing_face, "nx"), 0.006, "wood_light")

    return p, p.finish(material)


# =============================================================================
#  PLAYER CAR -- THE OPAQUE OUTER SHELL ONLY
# =============================================================================
#
# This split is not optional. build_player_car is also the driving-cutscene set:
# DRIVER_EYE sits inside it, six panes use alpha 0.35, four details emit light,
# and the pillars/steering furniture are pitched specifically for a 66-degree
# first-person frame. The one-material opaque atlas cannot preserve any of that.
# The GLB therefore stops at the belt line. Glass, lamps, pillars, dash, wheel,
# seats and roof soffit remain procedural; only the opaque exterior below moves.
#
# Source extrema are preserved rather than recentred to a prettier number:
# mirrors x -1.100..+1.100, tyres touch y 0, roof y 1.335..1.425, and bumpers
# z -2.550..+2.310. Local -Z is the nose, exactly like ExteriorProps.
#
# The primitive silhouette is deliberately improved, not merely fused. Tapers
# give the body shoulders and the nose a plan-view rake; 12-20 mm bevels catch
# light on the hood, roof, boot and bumpers; door skins have a real 6 mm inset;
# the wheels are flat-shaded decagons, not smooth CylinderMesh instances. No
# decorative face is coplanar: doors stand 5 mm proud of the body, seam strips
# stand another 1 mm proud, and wheel-arch brows stand outside both.


def build_player_car_shell(material):
    p = bb.Part("lp_player_car_shell")

    # Rotate a newly-authored upright prism onto the car's X axle. Part.prism
    # stands on Godot +Y; a -90-degree turn about Godot +Z sends that axis to +X.
    def axle_prism(centre, radius, width, sides, swatch, cap_swatch=None,
                   phase=0.0):
        mark = p.mark_verts()
        p.prism((centre[0], centre[1] - width * 0.5, centre[2]),
                radius, width, sides, swatch, cap_swatch=cap_swatch,
                phase=phase)
        verts = [v for v in p.bm.verts if v not in mark]
        pivot = bb.V(centre)
        matrix = (bb.Matrix.Translation(pivot)
                  @ bb.Matrix.Rotation(math.radians(-90.0), 4,
                                       bb.V((0.0, 0.0, 1.0)))
                  @ bb.Matrix.Translation(-pivot))
        bb.bmesh.ops.transform(p.bm, matrix=matrix, verts=verts)

    # ---- lower shell: one shouldered volume rather than a rectangular bath --
    body = p.taper((0.0, 0.290, 0.350), (1.680, 3.300), (1.780, 3.400),
                   0.520, "car_body", cap_bottom=True,
                   face_swatches={"py": "car_body_light", "ny": "car_body_dark"})
    p.bevel(p.facing(body, "py"), 0.018, "car_body_light")

    # The hood retains the source top at y 0.91, vital to DRIVER_EYE framing.
    # Its taper narrows 40 mm per side and the bevel gives the near-camera edge
    # a highlight without raising that surveyed top.
    hood = p.taper((0.0, 0.790, -1.620), (1.700, 1.350), (1.620, 1.290),
                   0.120, "car_body", cap_bottom=True,
                   face_swatches={"py": "car_body_light"})
    p.bevel(p.facing(hood, "py"), 0.020, "car_body_light")

    # Nose is wider at the shoulder and tighter at road level. The bevel is on
    # the leading -Z face, replacing the old square three-box junction.
    nose = p.taper((0.0, 0.350, -2.200), (1.620, 0.420), (1.740, 0.500),
                   0.460, "car_body", cap_bottom=True,
                   face_swatches={"py": "car_body_light", "ny": "car_body_dark"})
    p.bevel(p.facing(nose, "nz", tol=0.12), 0.035, "car_body_dark")

    boot = p.taper((0.0, 0.810, 1.750), (1.700, 0.900), (1.620, 0.840),
                   0.100, "car_body", cap_bottom=True,
                   face_swatches={"py": "car_body_light"})
    p.bevel(p.facing(boot, "py"), 0.016, "car_body_light")

    for z, face in ((-2.480, "nz"), (2.240, "pz")):
        bumper = p.box((0.0, 0.400, z), (1.800, 0.220, 0.140),
                       "car_trim", face_swatches={"ny": "shadow"})
        p.bevel(p.facing(bumper, face), 0.022, "car_trim")

    # Roof remains opaque and in the model; the soffit beneath it and all four
    # pillars stay procedural, so the cabin remains genuinely hollow.
    roof = p.taper((0.0, 1.335, 0.350), (1.640, 1.900), (1.540, 1.800),
                   0.090, "car_body", cap_bottom=True,
                   face_swatches={"py": "car_body_light", "ny": "car_body_dark"})
    p.bevel(p.facing(roof, "py"), 0.012, "car_body_light")

    # ---- doors and real panel depth --------------------------------------
    for side in (-1.0, 1.0):
        outward = "nx" if side < 0.0 else "px"
        door = p.box((side * 0.860, 0.680, 0.350),
                     (0.070, 0.550, 1.900), "car_body")
        p.inset(p.facing(door, outward), 0.075, -0.006,
                "car_body_dark", "car_body")
        # The centre break turns the old single slab into readable front/rear
        # doors. Offset 1 mm beyond the skin: no z-fighting at grazing angles.
        p.box((side * 0.896, 0.680, 0.350), (0.004, 0.480, 0.018),
              "shadow")
        # Angular wheel-arch brows. Tyres mask the lower ends; three facets are
        # enough to read as an arch without wasting a 32-segment torus.
        for wz in (-1.420, 1.320):
            p.box((side * 0.898, 0.665, wz), (0.005, 0.025, 0.360),
                  "car_body_dark")
            for dz in (-0.235, 0.235):
                mark = p.mark_verts()
                p.box((side * 0.898, 0.585, wz + dz),
                      (0.005, 0.200, 0.026), "car_body_dark")
                p.pitch(mark, (side * 0.898, 0.585, wz + dz),
                        -38.0 if dz < 0.0 else 38.0)

        # Wing mirror arm and bevelled housing retain the exact source extrema.
        p.box((side * 0.950, 1.000, -0.780),
              (0.140, 0.040, 0.050), "car_trim")
        mirror = p.box((side * 1.060, 1.020, -0.780),
                       (0.080, 0.140, 0.200), "car_trim")
        p.bevel(p.facing(mirror, outward), 0.012, "car_trim")

        # Four low-poly tyres and inset bright hubcaps. Width and centres match
        # the source, but 10 sides replace smooth 128-triangle CylinderMeshes.
        for wz in (-1.420, 1.320):
            # phase 0 puts a decagon vertex exactly at +/-Y after the axle
            # rotation: tyre radius 0.340 at centre y 0.340 then touches y 0.
            axle_prism((side * 0.840, 0.340, wz), 0.340, 0.250, 10,
                       "car_trim", cap_swatch="car_trim", phase=0.0)
            axle_prism((side * 0.976, 0.340, wz), 0.095, 0.020, 10,
                       "car_hubcap", cap_swatch="car_hubcap", phase=0.0)

    return p, p.finish(material)


BUILDERS = (build_stack_carriage, build_rotunda_bench, build_lobby_counter,
            build_player_car_shell)

BUDGET = {
    # Large fixture ceiling is 1200. The shell lands near 380, and the headroom
    # is deliberate: the shelves are NOT in this model and must not creep in.
    "lp_stack_carriage": 700,
    # Furniture ceiling is 400. Twenty-four boxes and seven chamfers land near
    # 350; anything past 400 means somebody added detail a bench does not need.
    "lp_rotunda_bench": 400,
    # Large fixture ceiling again: this is a 4.7 m L, not a chair. Twelve boxes,
    # three insets and five chamfers land near 300, so 600 leaves room for a
    # future drawer bank without letting the stone slabs creep in.
    "lp_lobby_counter": 600,
    # Vehicle ceiling is 1200. The decagonal wheels and genuine panel work are
    # the useful detail; 900 prevents the procedural cabin from creeping in.
    "lp_player_car_shell": 900,
}

# Per-model house-style rules, in metres.
RULES = {
    # No centre_z on purpose -- the handwheel stands proud of the operating
    # end, so the bbox runs -1.6225 .. +1.5175. See the header. max_y is the
    # dust panel 0.5 mm over the 2.200 cap, which is STACK_CARRIAGE_H.
    "lp_stack_carriage": {"floor_y": 0.0, "centre_x": True, "max_y": 2.201},
    # Floor is the brass foot plate. max_y is the back rail top at 1.030, the
    # figure the build_rotunda_bench doc comment quotes. No centre_z: the back
    # overhangs, see the block above the builder.
    "lp_rotunda_bench": {"floor_y": 0.0, "centre_x": True, "max_y": 1.030},
    # Floor is the toe kick. max_y is the fascia and end panel tops at 1.070:
    # 30 mm UNDER the 1.100 the stone ledge presents, because that slab is not
    # in this model. No centre_z -- the return wing, see the header.
    "lp_lobby_counter": {"floor_y": 0.0, "centre_x": True, "max_y": 1.070},
    # Source shell is asymmetric in Z: nose bumper -2.550, rear +2.310. Keep
    # that camera-critical offset; only X is centred. Roof top is y 1.425.
    "lp_player_car_shell": {"floor_y": 0.0, "centre_x": True, "max_y": 1.425},
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
    print("%-20s %-26s %6s %6s %9s"
          % ("model", "bbox W x H x D (m)", "tris", "faces", "bytes"))
    print("-" * 74)
    for name, lo, hi, size, tris, quads, nbytes in rows:
        print("%-20s %-26s %6d %6d %9d"
              % (name, "%.3f x %.3f x %.3f" % size, tris, quads, nbytes))
        print("%-20s x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f"
              % ("", lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    print("")

    if failures:
        for line in failures:
            print("FAIL", line)
        raise SystemExit(
            "blender_archive: %d house-style violation(s)" % len(failures))

    print("BUILD_OK", len(rows), "models")


if __name__ == "__main__":
    main()
