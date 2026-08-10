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


BUILDERS = (build_stack_carriage,)

BUDGET = {
    # Large fixture ceiling is 1200. The shell lands near 380, and the headroom
    # is deliberate: the shelves are NOT in this model and must not creep in.
    "lp_stack_carriage": 700,
}

# Per-model house-style rules, in metres.
RULES = {
    # No centre_z on purpose -- the handwheel stands proud of the operating
    # end, so the bbox runs -1.6225 .. +1.5175. See the header. max_y is the
    # dust panel 0.5 mm over the 2.200 cap, which is STACK_CARRIAGE_H.
    "lp_stack_carriage": {"floor_y": 0.0, "centre_x": True, "max_y": 2.201},
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
