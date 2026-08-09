"""Blender-authored low-poly CCTV hardware for museum-liminal.

RUN IT LIKE THIS (no GUI, nothing to click):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/lowpoly/blender_cameras.py

WHY A SECOND FILE INSTEAD OF ANOTHER BATCH IN blender_build.py
---------------------------------------------------------------
Everything structural is imported from blender_build: the Part class, the
bevel/inset wrappers, the palette material and the exporter, so these models
are the same 26 colours, the same one draw call and the same flat shading as
lp_desk_monitor and lp_stanchion. What cannot be shared is the house-style
check at the bottom of blender_build.main(), which asserts that a model's
floor is at y = 0 and that it is centred in X and Z. Both posts here hang from
a ceiling: the head is centred on the ball joint it pivots about and the plate
is measured from its ceiling face down. They are the "wall-mounted models are
the documented exception" case, so they get their own assertions.

WHAT THESE REPLACE
------------------
FirstMuseumMap._camera() builds every one of the eleven posts out of six
primitives: a plate, a drop stem, a ball joint, a 0.50 x 0.28 x 0.34 box for
the housing, a cylinder for the lens and a small emissive box for the record
LED. That was already better than what it replaced (models/camera.fbx is a
13.4 MB TRIPOD camera), but a plain box 3 m over the player's head with a
cylinder poking out of it never reads as a camera -- it reads as a box. These
two models take over the two parts of the post whose shape is fixed:

    lp_security_camera  the head: housing, sun shade, lens barrel and the
                        tilt-bracket cheeks that clamp the ball joint
    lp_camera_plate     the ceiling plate: chamfered pan, four bolt heads,
                        stem collar and cable boot

The drop stem stays procedural because its length is derived per post from the
soffit height, the ball joint stays procedural because the head pivots about
it, and the record LED stays procedural because it is emissive and nothing in
this pipeline emits.

COORDINATE SPACE
----------------
Godot/glTF space, exactly as in blender_build: +X right, +Y up, -Z forward,
1 unit = 1 metre. A camera looks along -Z, which matches _camera(): the mount
yaws so that -Z points at the target and the head then pitches down about X.

ORIGINS -- READ BEFORE MOVING A NUMBER
--------------------------------------
lp_security_camera has its origin at the CENTRE OF THE HOUSING, which is where
the head node sits, so the model drops in at Vector3.ZERO under that node and
lands exactly where the old body box was. The bracket cheeks rise to y = 0.16,
the ball joint's centre, so the ball caps the gap between them at every pitch
angle the eleven posts use.

lp_camera_plate has its origin on its CEILING FACE at y = 0 and hangs down
from there, so it is placed at (0, drop, 0) where drop is the soffit clearance
_camera() already computes.
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
# lp_security_camera -- 0.30 x 0.27 x 0.50 m, lens faces -Z
# =========================================================================
# Sizes are down from the 0.50 x 0.28 x 0.34 box they replace. Half a metre
# across is a fire hose reel, not a camera; 0.26 of housing under a 0.30 shade
# is a body that still reads from 3 m below while looking like hardware.
#
# Nothing here is coplanar with anything it sits on. Every add-on part is
# buried 3-15 mm inside the part it lands on -- the shade into the housing top,
# the barrel into the front face, the cap into the back. Two boxes that merely
# touch share a plane, and a shared plane is the shimmer this same audit round
# had to take out of the atrium floor.
def build_security_camera(material):
    p = bb.Part("lp_security_camera")

    # ---- housing ---------------------------------------------------------
    body_mark = p.mark_faces()
    p.box((0.0, 0.0, 0.0), (0.260, 0.200, 0.400), "carcass",
          face_swatches={"nz": "carcass_dark", "py": "carcass_side",
                         "px": "carcass_side", "nx": "carcass_side",
                         "ny": "shadow"})
    body = p.new_faces(body_mark)
    p.bevel(p.facing(body, "nz"), 0.014, "carcass_side")
    body = p.new_faces(body_mark)
    p.bevel(p.facing(body, "pz"), 0.010, "carcass_side")

    # ---- sun shade -------------------------------------------------------
    # Oversails the lens by 30 mm. On a camera this is the part that says
    # "camera" at a distance: it is the only horizontal line on the silhouette.
    # Its underside is at y = 0.093, i.e. 7 mm INSIDE the housing top.
    shade_mark = p.mark_faces()
    p.box((0.0, 0.104, -0.030), (0.300, 0.022, 0.360), "carcass_side",
          face_swatches={"ny": "shadow", "py": "top_cap"})
    shade = p.new_faces(shade_mark)
    p.bevel(p.facing(shade, "nz"), 0.008, "carcass_side")

    # Brackets tying the shade down to the housing flanks, 3 mm into both.
    for x in (-0.135, 0.135):
        p.box((x, 0.070, -0.120), (0.016, 0.070, 0.090), "handle_dark")

    # ---- lens barrel -----------------------------------------------------
    # Half buried in the front face at z = -0.200. Bevelled hard so twelve
    # edges of a cube read as a turned barrel rather than as a die.
    barrel_mark = p.mark_faces()
    p.box((0.0, -0.008, -0.190), (0.124, 0.124, 0.130), "handle_dark")
    barrel = p.new_faces(barrel_mark)
    p.bevel(barrel, 0.036, "handle_dark")
    barrel = p.new_faces(barrel_mark)
    # Real recess, 14 mm deep, so the glass sits in shadow instead of being a
    # sticker on the front of a box.
    p.inset(p.facing(barrel, "nz"), 0.014, -0.014, "shadow", "glass_dead")
    # Glass sits at z = -0.269; the sheen is 0.5 mm proud of it.
    p.panel((-0.014, 0.004, -0.2685), (0.020, 0.048), "glass_sheen", "nz")

    # ---- back of the head ------------------------------------------------
    # Cap and gland: the housing ends at z = +0.200, the cap is buried 15 mm
    # into it and the gland 20 mm into the cap.
    p.box((0.0, 0.0, 0.215), (0.220, 0.170, 0.060), "carcass_dark",
          face_swatches={"pz": "shadow"})
    p.box((0.0, 0.045, 0.258), (0.055, 0.055, 0.050), "handle_dark")

    # ---- tilt bracket ----------------------------------------------------
    # Two cheeks clamping the procedural ball joint, whose centre is at
    # y = 0.160 with r = 0.055. Inner faces at x = +-0.053 clear the ball by
    # 2 mm at the equator, and because the cheeks pitch WITH the head the ball
    # covers the gap between them at any angle the posts are aimed at.
    for x in (-0.062, 0.062):
        cheek_mark = p.mark_faces()
        p.box((x, 0.075, 0.0), (0.018, 0.180, 0.110), "carcass",
              face_swatches={"py": "handle_dark"})
        cheek = p.new_faces(cheek_mark)
        p.bevel(p.facing(cheek, "py"), 0.010, "handle_dark")

    # ---- painted detail --------------------------------------------------
    # 0.5 mm proud of the faces they lie on, the same margin the desk set uses.
    p.panel((0.1305, -0.040, 0.060), (0.110, 0.038), "label", "px")
    p.panel((-0.1305, -0.040, 0.060), (0.070, 0.026), "tag", "nx")
    p.panel((0.0, 0.1155, -0.040), (0.180, 0.240), "grime", "py")

    return p, p.finish(material)


# =========================================================================
# lp_camera_plate -- 0.28 x 0.10 x 0.28 m, ceiling face at y = 0
# =========================================================================
# The old plate was a 0.26 x 0.04 x 0.26 slab with nothing on it. A ceiling
# fixture is believable exactly when you can see how it was fixed, so this one
# has the four bolts, the collar the stem passes through and the boot the cable
# leaves by. It hangs DOWN from the origin: every y here is negative.
def build_camera_plate(material):
    p = bb.Part("lp_camera_plate")

    pan_mark = p.mark_faces()
    p.box((0.0, -0.015, 0.0), (0.280, 0.030, 0.280), "carcass",
          face_swatches={"py": "shadow", "ny": "carcass_dark"})
    pan = p.new_faces(pan_mark)
    p.bevel(p.facing(pan, "ny"), 0.012, "carcass_side")

    # Four bolt heads, 2 mm up inside the pan so no face is shared with it.
    for x in (-0.104, 0.104):
        for z in (-0.104, 0.104):
            p.box((x, -0.036, z), (0.032, 0.014, 0.032), "handle_dark")

    # Collar: the stem is 70 mm across, so this is what stops the stem looking
    # like it was pushed through a hole in a sheet of card.
    collar_mark = p.mark_faces()
    p.box((0.0, -0.052, 0.0), (0.104, 0.056, 0.104), "carcass_dark")
    collar = p.new_faces(collar_mark)
    p.bevel(p.facing(collar, "ny"), 0.012, "handle_dark")

    # Cable boot leaving to one side, and the tail of conduit it feeds.
    p.box((0.086, -0.040, 0.0), (0.062, 0.038, 0.070), "handle_dark")
    p.panel((0.0, -0.0305, 0.0), (0.190, 0.190), "grime", "ny")

    return p, p.finish(material)


BUILDERS = (build_security_camera, build_camera_plate)
BUDGET = {"lp_security_camera": 700, "lp_camera_plate": 400}
# (lo, hi) rules per model, in metres. None means "no rule".
RULES = {
    # Head: centred in X on the ball joint, and the shade must not be so long
    # that it fouls the ceiling plate 0.6 m above it.
    "lp_security_camera": {"centre_x": True, "max_y": 0.180},
    # Plate: ceiling face exactly at y = 0, centred in X and Z.
    "lp_camera_plate": {"centre_x": True, "centre_z": True, "top_y": 0.0},
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

        if rule.get("centre_x") and abs(lo[0] + hi[0]) > 2e-3:
            failures.append("%s: not centred in X (%.4f .. %.4f)"
                            % (part.name, lo[0], hi[0]))
        if rule.get("centre_z") and abs(lo[2] + hi[2]) > 2e-3:
            failures.append("%s: not centred in Z (%.4f .. %.4f)"
                            % (part.name, lo[2], hi[2]))
        if "top_y" in rule and abs(hi[1] - rule["top_y"]) > 1e-4:
            failures.append("%s: top face at y=%.4f, must be %.4f"
                            % (part.name, hi[1], rule["top_y"]))
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
    print("-" * 72)
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
            "blender_cameras: %d house-style violation(s)" % len(failures))

    print("BUILD_OK", len(rows), "models")


if __name__ == "__main__":
    main()
