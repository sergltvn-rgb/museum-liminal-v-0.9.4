"""Plan-view clearance and sightline checker for the containment core.

RUN IT LIKE THIS (plain system Python -- no Blender, no Godot, no imports):

    python tools/lowpoly/check_core_layout.py

WHY THIS FILE EXISTS
--------------------
blender_core.py ends its header with a promise: the core's angles "are
asserted against the placement code rather than eyeballed in a render".
Nothing actually asserted them. The result shipped: lp_core_gantry was
authored as a TANGENTIAL balcony while both AtriumProps._build_core_gantries
and its own primitive fallback assume a RADIAL gangway. The model exported,
passed every house-style rule in blender_core.RULES, imported, and moved the
MeshInstance3D count in test_map_verification -- so every green light in the
pipeline stayed green while three catwalks floated 190 mm short of the
machine they are supposed to be bolted to.

A triangle count cannot catch that. A render can, but only if somebody looks
at the render, and the capture rig currently writes frames too dark to
adjudicate. This file catches it arithmetically, in about 30 ms.

WHAT IT CHECKS
--------------
1. REACH      Every gantry deck must bite INTO the column rib cage at its
              inner end and oversail the base deck lip at its outer end. A
              deck that stops in mid-air at either end is the defect this
              whole file was written for.
2. FOULING    No two placed parts may overlap in plan while also overlapping
              in height. Plan-only overlap is fine and common (the skids pass
              under nothing). Height-only overlap is fine too. Both at once
              is geometry poking through geometry.
3. SIGHTLINE  The 305..325 degree sector stays clear, because security camera
              03 looks down the 317.2 degree ray from (13.6, 3.0, -12.6).
              That shot is the entire reason the fourth gantry was never
              built, and it is the invariant most easily closed by accident.

THE CONVENTION CLASH THAT CAUSED THE BUG -- READ BEFORE ADDING A PART
----------------------------------------------------------------------
Two different helpers put things on a radius, and they do NOT agree on which
local axis points outward:

    Models.place(..., yaw = 90 - A)   local +Z -> outward, local +X -> tangent
    AtriumProps._radial_box(..., A)   local +X -> outward, local +Z -> tangent

So Vector3(1.44, 0.10, 0.86) handed to _radial_box is 1.44 m RADIAL and
0.86 m tangential, while a model whose glTF X size is 1.44 placed by
Models.place is 1.44 m TANGENTIAL and its Z size is the radial one. The
fallback and the model it falls back from were written against opposite
conventions, which is precisely how the two ended up describing different
objects while every automated check passed.

Both mappings are implemented below as place_model() and place_radial_box().
Anything added to SCENE must use the one matching the helper that actually
places it in AtriumProps.gd. Guessing is how this bug happened once already.

NUMBERS ARE MIRRORED, NOT IMPORTED
----------------------------------
This script cannot import AtriumProps.gd or run Blender, so the AABBs and
radii below are transcribed by hand. That is a real hazard: an edit to
blender_core.py or AtriumProps.gd will not update them. Every entry therefore
carries the file and symbol it was copied from, and blender_core.main()
prints the true exported bbox of each model -- if a printed bbox and a MODELS
entry here disagree, this file is the one that is wrong.
"""

from __future__ import annotations

import math

# ==========================================================================
# Geometry
# ==========================================================================


class Rect:
    """An oriented rectangle in the XZ plane plus the Y band it occupies."""

    def __init__(self, label, centre, axis_a, axis_b, half_a, half_b, y0, y1):
        self.label = label
        self.c = centre
        self.axes = (axis_a, axis_b)
        self.h = (half_a, half_b)
        self.y0 = y0
        self.y1 = y1

    def corners(self):
        (ax, az), (bx, bz) = self.axes
        ha, hb = self.h
        return [(self.c[0] + sa * ha * ax + sb * hb * bx,
                 self.c[1] + sa * ha * az + sb * hb * bz)
                for sa, sb in ((-1.0, -1.0), (-1.0, 1.0),
                               (1.0, 1.0), (1.0, -1.0))]

    def boundary(self, per_edge=90):
        ring = self.corners()
        pts = []
        for i in range(4):
            x0, z0 = ring[i]
            x1, z1 = ring[(i + 1) % 4]
            for k in range(per_edge):
                f = float(k) / float(per_edge)
                pts.append((x0 + (x1 - x0) * f, z0 + (z1 - z0) * f))
        return pts


def _project(rect, axis):
    c = rect.c[0] * axis[0] + rect.c[1] * axis[1]
    r = 0.0
    for (ax, az), h in zip(rect.axes, rect.h):
        r += abs((ax * axis[0] + az * axis[1]) * h)
    return c - r, c + r


def plan_gap(p, q):
    """Separating-axis gap in metres. Negative means the two overlap."""
    best = -1.0e9
    for axis in (p.axes[0], p.axes[1], q.axes[0], q.axes[1]):
        p0, p1 = _project(p, axis)
        q0, q1 = _project(q, axis)
        best = max(best, max(q0 - p1, p0 - q1))
    return best


def height_gap(p, q):
    return max(q.y0 - p.y1, p.y0 - q.y1)


def azimuth_span(rect, about_deg):
    """Compass range the rectangle covers, unwrapped around `about_deg`."""
    lo = hi = None
    for x, z in rect.boundary():
        d = math.degrees(math.atan2(z, x)) - about_deg
        d = (d + 180.0) % 360.0 - 180.0
        lo = d if lo is None else min(lo, d)
        hi = d if hi is None else max(hi, d)
    return about_deg + lo, about_deg + hi


def place_model(label, aabb, angle_deg, radius, y_base):
    """Models.place(): yaw = 90 - A, so local +Z is outward, +X tangential."""
    a = math.radians(angle_deg)
    outward = (math.cos(a), math.sin(a))
    tangent = (math.sin(a), -math.cos(a))
    lo, hi = aabb
    ox = 0.5 * (lo[0] + hi[0])
    oz = 0.5 * (lo[2] + hi[2])
    centre = (outward[0] * (radius + oz) + tangent[0] * ox,
              outward[1] * (radius + oz) + tangent[1] * ox)
    return Rect(label, centre, tangent, outward,
                0.5 * (hi[0] - lo[0]), 0.5 * (hi[2] - lo[2]),
                y_base + lo[1], y_base + hi[1])


def place_radial_box(label, angle_deg, radius, y, size, offset=0.0):
    """_radial_box(): yaw = -A, so local +X is outward, +Z tangential."""
    a = math.radians(angle_deg)
    outward = (math.cos(a), math.sin(a))
    tangent = (-math.sin(a), math.cos(a))
    centre = (outward[0] * radius + tangent[0] * offset,
              outward[1] * radius + tangent[1] * offset)
    return Rect(label, centre, outward, tangent,
                0.5 * size[0], 0.5 * size[2],
                y - 0.5 * size[1], y + 0.5 * size[1])


# ==========================================================================
# The core, transcribed. Source file and symbol on every line.
# ==========================================================================

DECK_Y = 0.24          # AtriumProps._build_core_gantries / _build_core_plant
RIB_OUTER_R = 0.740    # blender_core.build_core_column, rib box x 0.540..0.740
SLAB_EDGE_R = 2.050    # blender_core.build_core_base, deck prism radius
LIP_R = 2.220          # blender_core.build_core_base, plinth lip radius
CAM03_RAY = 317.2      # FirstMuseumMap security camera 03, (13.6, 3.0, -12.6)
FREE_SECTOR = (305.0, 325.0)

# The column model is placed on the assembly axis; its own swing() angles are
# therefore compass angles with no extra yaw. If _build_core_column ever gains
# a yaw argument this constant has to follow it.
COLUMN_YAW = 0.0

# blender_core.build_core_gantry, before and after the radial rewrite.
GANTRY_TANGENTIAL = ((-0.720, 0.000, -0.430), (0.720, 1.990, 0.445))
DECK_TANGENTIAL = ((-0.720, 0.920, -0.430), (0.720, 1.020, 0.430))
GANTRY_RADIAL = ((-0.475, 0.000, -0.720), (0.475, 1.995, 0.735))
DECK_RADIAL = ((-0.430, 0.920, -0.720), (0.430, 1.020, 0.720))

# blender_core.build_core_plant. hi_y is the riser elbow at 1.585 + 0.050.
PLANT = ((-0.450, 0.000, -0.2605), (0.450, 1.635, 0.2605))
PLANT_R = 1.20

GANTRY_ANGLES = (45.0, 135.0, 225.0)
GANTRY_R = 1.36


def static_parts():
    """Everything on the dais that is not a gantry or a skid."""
    parts = []
    # blender_core.build_core_column: eight cage ribs on TAU*i/8 + PI/8.
    for i in range(8):
        deg = COLUMN_YAW + 22.5 + 45.0 * i
        parts.append(place_radial_box(
            "Cage rib %d" % i, deg, 0.640, DECK_Y + 1.200,
            (0.200, 0.860, 0.140)))
    # AtriumProps._build_core_shutters: four headers, two south rails.
    for i in range(4):
        parts.append(place_radial_box(
            "Shutter header %d" % i, 90.0 * i, 1.70, 2.62,
            (0.30, 0.34, 1.50)))
    for side in (-1.0, 1.0):
        parts.append(place_radial_box(
            "Shutter rail %+d" % side, 90.0, 1.70, 1.35,
            (0.13, 2.20, 0.13), offset=side * 0.70))
    # AtriumProps._build_core_shutters: the lp_blast_shutter curtain, placed
    # at (0, 1.60, 1.70) with yaw 180 -- i.e. on the south ray at r 1.70.
    parts.append(place_model(
        "Blast shutter curtain",
        ((-0.670, 0.000, -0.075), (0.670, 0.860, 0.075)),
        90.0, 1.70, 1.60))
    return parts


def build_scene(gantry_aabb, skid_angles):
    scene = list(static_parts())
    for i, deg in enumerate(GANTRY_ANGLES):
        scene.append(place_model(
            "Gantry %d @%g" % (i + 1, deg), gantry_aabb, deg,
            GANTRY_R, DECK_Y))
    for deg in skid_angles:
        scene.append(place_model(
            "Skid @%g" % deg, PLANT, deg, PLANT_R, DECK_Y))
    return scene


# ==========================================================================
# Checks
# ==========================================================================


def check_reach(deck_aabb, failures):
    lo, hi = deck_aabb
    inner = GANTRY_R + lo[2]
    outer = GANTRY_R + hi[2]
    bite = RIB_OUTER_R - inner
    oversail = outer - SLAB_EDGE_R
    print("  deck reaches r %.3f .. %.3f along its own ray" % (inner, outer))
    print("    inner end vs rib cage r %.3f : %+.3f m"
          % (RIB_OUTER_R, bite))
    print("    outer end vs slab edge r %.3f: %+.3f m"
          % (SLAB_EDGE_R, oversail))
    if bite < 0.020:
        failures.append(
            "gantry deck inner end at r %.3f does not bite the rib cage "
            "(r %.3f); short by %.3f m" % (inner, RIB_OUTER_R, -bite))
    if oversail < 0.0:
        failures.append(
            "gantry deck outer end at r %.3f stops short of the slab edge "
            "(r %.3f) by %.3f m" % (outer, SLAB_EDGE_R, -oversail))
    if outer > LIP_R:
        failures.append(
            "gantry deck outer end at r %.3f oversails the plinth lip "
            "(r %.3f)" % (outer, LIP_R))


# Joins that are SUPPOSED to intersect. This pipeline's entire anti-shimmer
# idiom is "bury every part 5-15 mm in the one below it", so a checker with no
# allowance for that cries wolf on every correct joint and gets ignored. Each
# entry caps how deep its join may go: past the cap it has stopped being a
# joint and become two objects sharing a volume.
DELIBERATE = (
    ("Cage rib", "Gantry", 0.105,
     "the deck's inner end lands ON the machine; REACH owns its depth"),
    ("Shutter header", "Blast shutter curtain", 0.240,
     "the curtain hangs from inside its header"),
    ("Shutter rail", "Blast shutter curtain", 0.050,
     "the curtain runs in its rails"),
)


def deliberate_cap(a, b):
    for pa, pb, cap, _why in DELIBERATE:
        if ((a.startswith(pa) and b.startswith(pb))
                or (a.startswith(pb) and b.startswith(pa))):
            return cap
    return None


def check_fouling(scene, failures):
    worst = []
    joins = 0
    for i in range(len(scene)):
        for j in range(i + 1, len(scene)):
            p, q = scene[i], scene[j]
            pg = plan_gap(p, q)
            hg = height_gap(p, q)
            if pg >= 0.0 or hg >= 0.0:
                if pg < 0.040 and hg < 0.0:
                    worst.append((pg, p.label, q.label))
                continue
            cap = deliberate_cap(p.label, q.label)
            if cap is not None and -pg <= cap:
                joins += 1
                continue
            failures.append(
                "%s and %s interpenetrate: %.3f m in plan, %.3f m in height%s"
                % (p.label, q.label, -pg, -hg,
                   "" if cap is None
                   else " -- past its %.3f m join cap" % cap))
    print("  %d deliberate join(s), all inside their caps" % joins)
    for pg, a, b in sorted(worst)[:6]:
        print("  tight: %-22s vs %-22s %.3f m" % (a, b, pg))
    if not worst:
        print("  no pair closer than 40 mm")


def check_sightline(scene, failures):
    lo_s, hi_s = FREE_SECTOR
    intruders = []
    for rect in scene:
        mid = math.degrees(math.atan2(rect.c[1], rect.c[0]))
        a0, a1 = azimuth_span(rect, mid)
        for shift in (-360.0, 0.0, 360.0):
            s0, s1 = a0 + shift, a1 + shift
            if s1 > lo_s and s0 < hi_s:
                intruders.append((rect.label, s0, s1))
    for label, s0, s1 in intruders:
        failures.append(
            "%s spans %.1f..%.1f deg and enters the %g..%g free sector"
            % (label, s0, s1, lo_s, hi_s))
    if not intruders:
        print("  %g..%g deg clear; CAM 03 ray at %.1f deg unobstructed"
              % (lo_s, hi_s, CAM03_RAY))


def margin_for(skid_deg):
    """Degrees of clear sector left on the CAM 03 side of one skid."""
    rect = place_model("probe", PLANT, skid_deg, PLANT_R, DECK_Y)
    a0, a1 = azimuth_span(rect, skid_deg)
    return a0, a1


def solve_skid_angles():
    """Widest pair of skid angles that leaves the free sector untouched."""
    lo_s, hi_s = FREE_SECTOR
    low = None
    for step in range(0, 601):
        deg = 300.0 - 0.1 * step
        if margin_for(deg)[1] <= lo_s:
            low = deg
            break
    high = None
    for step in range(0, 601):
        deg = 330.0 + 0.1 * step
        if margin_for(deg)[0] >= hi_s:
            high = deg
            break
    return low, high


def run(title, gantry_aabb, deck_aabb, skid_angles):
    print("")
    print("=" * 74)
    print(title)
    print("=" * 74)
    failures = []
    print("REACH")
    check_reach(deck_aabb, failures)
    scene = build_scene(gantry_aabb, skid_angles)
    print("FOULING  (%d parts, %d pairs)"
          % (len(scene), len(scene) * (len(scene) - 1) // 2))
    check_fouling(scene, failures)
    print("SIGHTLINE")
    check_sightline(scene, failures)
    print("")
    if failures:
        for line in failures:
            print("  FAIL", line)
        print("  %d violation(s)" % len(failures))
    else:
        print("  LAYOUT_OK")
    return failures


def main():
    low, high = solve_skid_angles()
    print("Skid solver: the free sector %g..%g stays clear for any skid at or "
          "below" % FREE_SECTOR)
    print("  %.1f deg on the low side and at or above %.1f deg on the high "
          "side." % (low, high))
    for probe in (285.0, 345.0, 279.0, 351.0):
        a0, a1 = margin_for(probe)
        print("  skid @%-6.1f spans %7.1f .. %7.1f deg" % (probe, a0, a1))

    run("BEFORE -- tangential gantry, skids at 285 / 345",
        GANTRY_TANGENTIAL, DECK_TANGENTIAL, (285.0, 345.0))
    after = run("AFTER -- radial gantry, skids at 279 / 351",
                GANTRY_RADIAL, DECK_RADIAL, (279.0, 351.0))
    raise SystemExit(1 if after else 0)


if __name__ == "__main__":
    main()
