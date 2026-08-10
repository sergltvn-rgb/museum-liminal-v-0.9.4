"""Low-poly GLB authoring toolchain for museum-liminal.

WHY THIS EXISTS
---------------
Every prop in game/props/*.gd is assembled from Godot primitives -- BoxMesh,
CylinderMesh, SphereMesh -- one MeshInstance3D and one StandardMaterial3D per
part. That works, but it caps how good the props can look:

  * A CylinderMesh is smooth-shaded with 16-32 sides. That is the opposite of
    the faceted PS1-era silhouette this game is going for. You cannot get a
    hard-edged 8-sided pipe out of it without editing the mesh by hand.
  * A cabinet made of 14 primitives is 14 draw calls and 14 materials. A
    cabinet authored as one mesh is one of each.
  * Nothing can be chamfered, inset, bevelled or notched. Every shape is an
    axis-aligned box, which is why the props read as "programmer art".

This module writes real glTF 2.0 binary (.glb) assets instead, which Godot
imports as ordinary models and MapModels.place() already knows how to load.

NO BLENDER AND NO PIP PACKAGES ARE REQUIRED. glTF is a JSON manifest plus one
binary blob, and the palette atlas PNG is written with zlib from the standard
library. If Blender is installed later, these same models can be opened,
edited and re-exported from it -- .glb is Blender's native interchange format,
so nothing here is a dead end.

HOUSE STYLE -- every generated model obeys all of it
----------------------------------------------------
1 unit = 1 metre.

  Origin at the FLOOR, centred in X and Z. models/README.md states this and
  MapModels.place() relies on it: the caller passes a world position that is a
  point on the floor, not the centre of the object.

  Wall-mounted models are the one exception: their origin sits at the centre
  of the BACK face, the bit that touches the wall, and their body extends
  towards -Z. Each such model says so in its own docstring.

Forward is -Z (Godot standard), so rotation_y_deg at the call site means the
same thing for a generated model as for the procedural fallback it replaces.

FLAT SHADING ONLY. Every triangle carries its own three vertices and its own
face normal; nothing is ever smoothed and no two triangles share a vertex.
This is the single most important rule here -- it is what makes a 10-sided
cylinder read as a deliberate low-poly shape rather than as a badly
tessellated smooth one. It costs 3 vertices per triangle instead of ~1, which
at these poly counts is nothing.

ONE MATERIAL AND ONE TEXTURE PER MODEL. Colour is chosen by pointing a UV at a
swatch in a palette atlas baked from game/props/Palette.gd. Consequences:
  * a whole prop is a single draw call;
  * no generated model can drift off-palette, because there is no way to
    express a colour that is not in the palette;
  * retinting the game later means rebaking one 128x128 PNG.

NO NORMAL MAPS, NO METAL, NO EMISSION. metallicFactor 0 / roughnessFactor 0.92
is exactly what MaterialLib.apply_flat_style() forces onto the procedural
materials (FLAT_STYLE = true), so an imported prop and a code-built prop
standing next to each other light identically. Emission is never used: the art
direction is dense darkness with few light sources, and a glowing prop breaks
it instantly.

POLY BUDGET, per prop class. These are ceilings, not targets:
  small dressing (handle, label, sign)        <  60 tris
  furniture (cabinet, desk, chair, shelf)     < 400 tris
  large fixture (machine, vehicle, statue)    < 1200 tris
For reference the smooth-shaded CylinderMesh the props use today is 128 tris
BY ITSELF, so an entire 350-triangle cabinet is cheaper than three of them.

USAGE
-----
    from glb import Mesh, write_glb

    m = Mesh("lp_metal_locker")
    m.box((0.0, 1.0, 0.0), (0.9, 1.84, 0.5), "carcass")
    write_glb("models/lowpoly/lp_metal_locker.glb", m)

Run tools/lowpoly/build_props.py to regenerate every model.
"""

from __future__ import annotations

import json
import math
import os
import struct
import zlib

# =========================================================================
# 1. PALETTE -- mirrors game/props/Palette.gd
# =========================================================================
# The seven canon hues plus the role colours the props actually use. Values
# are copied verbatim from Palette.gd so the two never disagree; tone() and
# mixed() reproduce Godot's Color.lightened()/darkened()/lerp() exactly.


def darkened(c, amount):
    """Godot Color.darkened(): scales towards black."""
    f = 1.0 - amount
    return (c[0] * f, c[1] * f, c[2] * f)


def lightened(c, amount):
    """Godot Color.lightened(): scales towards white."""
    return (c[0] + (1.0 - c[0]) * amount,
            c[1] + (1.0 - c[1]) * amount,
            c[2] + (1.0 - c[2]) * amount)


def tone(c, amount):
    """Palette.tone(): positive lightens, negative darkens."""
    return lightened(c, amount) if amount >= 0.0 else darkened(c, -amount)


def mixed(c, towards, amount):
    """Palette.mixed(): straight lerp between two colours."""
    return (c[0] + (towards[0] - c[0]) * amount,
            c[1] + (towards[1] - c[1]) * amount,
            c[2] + (towards[2] - c[2]) * amount)


# --- canon hues -----------------------------------------------------------
INK = (0.067, 0.082, 0.094)
SLATE = (0.263, 0.345, 0.396)
BEIGE = (0.776, 0.725, 0.580)
MOSS = (0.506, 0.659, 0.541)
AMBER = (0.835, 0.604, 0.259)
RUST = (0.710, 0.290, 0.259)
LILAC = (0.780, 0.718, 0.851)

# --- material bases -------------------------------------------------------
STONE = (0.580, 0.550, 0.470)
WOOD = (0.220, 0.150, 0.085)
DESK = (0.165, 0.135, 0.095)
STEEL = (0.400, 0.460, 0.500)
STEEL_DARK = (0.160, 0.190, 0.210)
BRASS = (0.500, 0.380, 0.170)
CASING = (0.105, 0.118, 0.130)
SHELL = (0.062, 0.072, 0.082)
DARK = (0.035, 0.041, 0.048)
SIGN_TEXT = (0.800, 0.820, 0.780)
SCREEN_DEAD = (0.020, 0.024, 0.028)

# --- the atlas -----------------------------------------------------------
# Insertion order IS the atlas index, so appending is safe and reordering is
# not. Every swatch here is deliberately dark: the game is lit by a handful of
# hard point lights against near-black, and a mid-grey prop reads as glowing.
# The rule from the art direction is at most two bright spots in a frame, so
# nothing above ~0.45 luma belongs in a prop that fills the screen.
SWATCHES = {
    # Steel furniture: carcass, doors, caps.
    "carcass": tone(STEEL, -0.62),
    "carcass_dark": tone(STEEL, -0.74),
    "carcass_side": tone(STEEL, -0.68),
    "door": tone(SLATE, -0.46),
    "door_dark": tone(SLATE, -0.60),
    "door_light": tone(SLATE, -0.34),
    "top_cap": tone(STEEL, -0.55),
    "plinth": tone(CASING, -0.10),
    # Shadow lines. Used for the gap between two doors, under a drawer lip,
    # inside a vent slot: the cheap trick that gives a flat box depth.
    "shadow": DARK,
    "shadow_soft": tone(SHELL, -0.30),
    # Hardware.
    "handle": tone(STEEL, -0.20),
    "handle_dark": tone(STEEL, -0.44),
    "lock": tone(BRASS, -0.34),
    "hinge": tone(STEEL, -0.38),
    # Paper and labels -- small accents only, never a whole face.
    "label": tone(BEIGE, -0.70),
    "label_ink": tone(INK, 0.04),
    "glass_dead": SCREEN_DEAD,
    # Wood.
    "wood": WOOD,
    "wood_light": tone(WOOD, 0.16),
    "wood_dark": tone(WOOD, -0.34),
    # Wear and accents.
    # Rust is mixed towards CASING rather than just darkened: pure dark RUST
    # still reads as a saturated orange rectangle at this light level, which
    # looks like a decal rather than corrosion.
    "rust": mixed(tone(RUST, -0.66), CASING, 0.42),
    "tag": tone(RUST, -0.34),
    # Grime has to be clearly DARKER than the carcass it sits on or it does
    # nothing at all; the first pass was within 0.02 luma of "carcass".
    "grime": tone(STONE, -0.85),
    "steel_bright": tone(STEEL, -0.08),
    # Appended after the first visual review. Appending is safe -- insertion
    # order is the atlas index, so no existing swatch shifts.
    "brace": tone(STEEL, -0.82),
    "glass_sheen": tone(SLATE, -0.62),
    # Appended for the atrium reception worktop. Every swatch above tops out
    # near 0.37 luma -- fine on a locker standing against a lit wall, but on a
    # 3.9 m counter lit only by atrium ambient the whole desk read as one black
    # monolith from the entrance doorway 13 m away. This is the first swatch
    # light enough to still read as stone at that distance in that light.
    "stone_pale": tone(STONE, -0.08),
    # Appended for the player's service-issue beige sedan. These are exact
    # ExteriorProps.build_player_car colours (or controlled steps of the same
    # body colour), not a generic furniture grey: the bonnet fills the bottom
    # third of the driving POV, where even a small palette mismatch is obvious.
    "car_body": (0.360, 0.330, 0.280),
    "car_body_light": tone((0.360, 0.330, 0.280), 0.10),
    "car_body_dark": tone((0.360, 0.330, 0.280), -0.18),
    "car_trim": tone(CASING, -0.15),
    "car_hubcap": tone(STONE, 0.05),
}

# 8 columns of 16 px blocks = 128 px, and the image is forced square and
# power-of-two so mipmapping behaves. Unused blocks are filled with DARK
# rather than a debug colour on purpose: no UV points at them, but mip level 4
# and above averages neighbouring blocks together, and bleeding a dark grey
# into a dark grey is invisible while bleeding magenta would not be.
ATLAS_COLS = 8
ATLAS_BLOCK = 16
ATLAS_SIZE = ATLAS_COLS * ATLAS_BLOCK  # 128


def swatch_index(name):
    try:
        return list(SWATCHES.keys()).index(name)
    except ValueError:
        raise KeyError(
            "unknown swatch %r -- add it to SWATCHES in tools/lowpoly/glb.py "
            "(and keep it dark; see the note above SWATCHES)" % (name,))


def uv_for(name):
    """Centre of the swatch's block, in glTF UV space (origin top-left)."""
    i = swatch_index(name)
    col = i % ATLAS_COLS
    row = i // ATLAS_COLS
    u = (col + 0.5) * ATLAS_BLOCK / float(ATLAS_SIZE)
    v = (row + 0.5) * ATLAS_BLOCK / float(ATLAS_SIZE)
    return (u, v)


def _srgb_byte(x):
    """Palette values are authored in the same space Godot's Color literals
    are, and a PNG baseColorTexture is read back in that same space, so this
    is a straight 0..1 -> 0..255 quantisation with no gamma conversion."""
    return max(0, min(255, int(round(x * 255.0))))


def atlas_png_bytes():
    """Bake SWATCHES into a PNG, written by hand so PIL is not needed."""
    names = list(SWATCHES.keys())
    rows_needed = (len(names) + ATLAS_COLS - 1) // ATLAS_COLS
    if rows_needed * ATLAS_BLOCK > ATLAS_SIZE:
        raise ValueError(
            "palette overflows the atlas: %d swatches need %d rows but only "
            "%d fit. Raise ATLAS_COLS or ATLAS_SIZE."
            % (len(names), rows_needed, ATLAS_SIZE // ATLAS_BLOCK))

    fill = (_srgb_byte(DARK[0]), _srgb_byte(DARK[1]), _srgb_byte(DARK[2]))
    # One byte triple per pixel, laid out row by row.
    pixels = [[fill] * ATLAS_SIZE for _ in range(ATLAS_SIZE)]
    for i, name in enumerate(names):
        c = SWATCHES[name]
        rgb = (_srgb_byte(c[0]), _srgb_byte(c[1]), _srgb_byte(c[2]))
        col = i % ATLAS_COLS
        row = i // ATLAS_COLS
        for y in range(row * ATLAS_BLOCK, (row + 1) * ATLAS_BLOCK):
            line = pixels[y]
            for x in range(col * ATLAS_BLOCK, (col + 1) * ATLAS_BLOCK):
                line[x] = rgb

    raw = bytearray()
    for line in pixels:
        raw.append(0)  # PNG filter type 0 (None) for this scanline
        for rgb in line:
            raw.extend(rgb)

    def chunk(tag, data):
        out = struct.pack(">I", len(data)) + tag + data
        return out + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", ATLAS_SIZE, ATLAS_SIZE, 8, 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))


# =========================================================================
# 2. GEOMETRY
# =========================================================================


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def _normalise(v):
    n = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if n < 1e-12:
        return (0.0, 1.0, 0.0)
    return (v[0] / n, v[1] / n, v[2] / n)


def _rotate(v, rot):
    """Euler degrees applied in Godot's default YXZ order, so a rotation typed
    here matches the same numbers typed into a Node3D's rotation_degrees."""
    if rot is None:
        return v
    rx, ry, rz = (math.radians(rot[0]), math.radians(rot[1]),
                  math.radians(rot[2]))
    x, y, z = v
    # Z
    if rz:
        cz, sz = math.cos(rz), math.sin(rz)
        x, y = x * cz - y * sz, x * sz + y * cz
    # X
    if rx:
        cx, sx = math.cos(rx), math.sin(rx)
        y, z = y * cx - z * sx, y * sx + z * cx
    # Y
    if ry:
        cy, sy = math.cos(ry), math.sin(ry)
        x, z = x * cy + z * sy, -x * sy + z * cy
    return (x, y, z)


# Face vertex orders for a unit box, each listed counter-clockwise as seen
# from outside so glTF's front-face rule gives an outward normal. Signs are
# multipliers on the half-extents.
_BOX_FACES = {
    "px": (((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1))),
    "nx": (((-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1))),
    "py": (((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1))),
    "ny": (((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1))),
    "pz": (((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1))),
    "nz": (((-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1))),
}
ALL_FACES = ("px", "nx", "py", "ny", "pz", "nz")


class Mesh:
    """A flat-shaded triangle soup with palette UVs.

    Deliberately dumb: no vertex sharing, no smoothing groups, no welding.
    Every helper appends independent triangles. At these poly counts the
    memory cost is irrelevant and the payoff is that a face's shading can
    never be contaminated by its neighbour.
    """

    def __init__(self, name):
        self.name = name
        self.pos = []
        self.nrm = []
        self.uv = []
        self.idx = []

    # -- primitives --------------------------------------------------------

    def tri(self, a, b, c, swatch):
        n = _normalise(_cross(_sub(b, a), _sub(c, a)))
        u, v = uv_for(swatch)
        base = len(self.pos) // 3
        for p in (a, b, c):
            self.pos.extend(p)
            self.nrm.extend(n)
            self.uv.extend((u, v))
        self.idx.extend((base, base + 1, base + 2))

    def quad(self, a, b, c, d, swatch):
        """Planar quad, wound a->b->c->d. Emitted as two independent tris."""
        self.tri(a, b, c, swatch)
        self.tri(a, c, d, swatch)

    def box(self, centre, size, swatch, faces=None, face_swatches=None,
            rot=None):
        """Axis-aligned box, optionally rotated about its own centre.

        faces          -- iterable of face keys to emit. Drop the ones that are
                          buried inside other geometry or flush against a wall;
                          a hidden face is pure waste and, if the prop is ever
                          seen from behind, a visible backface.
        face_swatches  -- per-face overrides, e.g. {"py": "top_cap"}.
        """
        hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        keys = ALL_FACES if faces is None else faces
        overrides = face_swatches or {}
        for key in keys:
            corners = _BOX_FACES[key]
            pts = []
            for sx, sy, sz in corners:
                local = (sx * hx, sy * hy, sz * hz)
                local = _rotate(local, rot)
                pts.append((centre[0] + local[0],
                            centre[1] + local[1],
                            centre[2] + local[2]))
            self.quad(pts[0], pts[1], pts[2], pts[3],
                      overrides.get(key, swatch))

    def panel(self, centre, size, swatch, axis="pz", rot=None):
        """A single flat quad -- a painted marking rather than a solid.

        This is how vent slots, drawer labels, seams and stencilled numbers are
        done: two triangles floating a couple of millimetres in front of the
        surface they decorate. Godot 4 uses a reverse-Z float depth buffer, so
        at the 1-4 m the player sees a cabinet from, 2 mm is thousands of times
        the depth resolution and cannot z-fight.

        size is (width, height) in the plane of `axis`.
        """
        w, h = size[0] * 0.5, size[1] * 0.5
        if axis in ("pz", "nz"):
            local = [(-w, -h, 0.0), (w, -h, 0.0), (w, h, 0.0), (-w, h, 0.0)]
        elif axis in ("px", "nx"):
            local = [(0.0, -h, -w), (0.0, h, -w), (0.0, h, w), (0.0, -h, w)]
        else:  # py / ny
            local = [(-w, 0.0, -h), (-w, 0.0, h), (w, 0.0, h), (w, 0.0, -h)]
        if axis in ("nz", "nx", "ny"):
            local.reverse()
        pts = []
        for p in local:
            p = _rotate(p, rot)
            pts.append((centre[0] + p[0], centre[1] + p[1], centre[2] + p[2]))
        self.quad(pts[0], pts[1], pts[2], pts[3], swatch)

    def cylinder(self, centre, radius, height, sides, swatch,
                 cap_swatch=None, cap_top=True, cap_bottom=True, rot=None,
                 phase=0.0):
        """Flat-shaded prism. `sides` is the whole point: use 6-10 for pipes and
        posts, 12 only for something the player will stand next to. Never more
        than 16 -- past that it stops reading as low-poly."""
        cap_swatch = cap_swatch or swatch
        hy = height * 0.5
        ring = []
        for i in range(sides):
            a = phase + 2.0 * math.pi * i / sides
            ring.append((radius * math.cos(a), radius * math.sin(a)))

        def place(x, y, z):
            p = _rotate((x, y, z), rot)
            return (centre[0] + p[0], centre[1] + p[1], centre[2] + p[2])

        for i in range(sides):
            x0, z0 = ring[i]
            x1, z1 = ring[(i + 1) % sides]
            self.quad(place(x0, -hy, z0), place(x0, hy, z0),
                      place(x1, hy, z1), place(x1, -hy, z1), swatch)
        if cap_top:
            c = place(0.0, hy, 0.0)
            for i in range(sides):
                x0, z0 = ring[i]
                x1, z1 = ring[(i + 1) % sides]
                self.tri(c, place(x1, hy, z1), place(x0, hy, z0), cap_swatch)
        if cap_bottom:
            c = place(0.0, -hy, 0.0)
            for i in range(sides):
                x0, z0 = ring[i]
                x1, z1 = ring[(i + 1) % sides]
                self.tri(c, place(x0, -hy, z0), place(x1, -hy, z1), cap_swatch)

    def taper(self, base_centre, bottom_xz, top_xz, height, swatch,
              cap_top=True, cap_bottom=False, rot=None):
        """Tapered four-sided box standing on `base_centre`.

        This is the one shape a BoxMesh cannot give you and the one that does
        the most work visually: a plinth that narrows towards the floor, a
        chamfered lid, a splayed foot. Two of these stacked make a prop stop
        looking like a stack of cubes.
        """
        bx, bz = bottom_xz[0] * 0.5, bottom_xz[1] * 0.5
        tx, tz = top_xz[0] * 0.5, top_xz[1] * 0.5

        def place(x, y, z):
            p = _rotate((x, y, z), rot)
            return (base_centre[0] + p[0], base_centre[1] + p[1],
                    base_centre[2] + p[2])

        b = [place(-bx, 0.0, -bz), place(bx, 0.0, -bz),
             place(bx, 0.0, bz), place(-bx, 0.0, bz)]
        t = [place(-tx, height, -tz), place(tx, height, -tz),
             place(tx, height, tz), place(-tx, height, tz)]
        # -Z, +X, +Z, -X walls, each wound outward.
        self.quad(b[0], t[0], t[1], b[1], swatch)
        self.quad(b[1], t[1], t[2], b[2], swatch)
        self.quad(b[2], t[2], t[3], b[3], swatch)
        self.quad(b[3], t[3], t[0], b[0], swatch)
        if cap_top:
            self.quad(t[0], t[3], t[2], t[1], swatch)
        if cap_bottom:
            self.quad(b[0], b[1], b[2], b[3], swatch)

    # -- reporting ---------------------------------------------------------

    @property
    def tri_count(self):
        return len(self.idx) // 3

    @property
    def vert_count(self):
        return len(self.pos) // 3

    def bounds(self):
        if not self.pos:
            return (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)
        xs = self.pos[0::3]
        ys = self.pos[1::3]
        zs = self.pos[2::3]
        return ((min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs)))

    def check(self, require_floor=True):
        """Cheap sanity pass. Returns a list of complaints, empty when clean.

        These are exactly the defects that cost a re-capture cycle when they
        slip through: a prop sunk into the floor, a prop floating above it, a
        degenerate triangle that renders as a black needle.

        require_floor is False for wall-mounted models, whose origin is the
        centre of the back face rather than a point on the floor.
        """
        problems = []
        lo, hi = self.bounds()
        if require_floor and lo[1] < -0.0005:
            problems.append(
                "geometry reaches %.4f m below the origin plane; the origin "
                "must sit on the floor" % lo[1])
        if require_floor and lo[1] > 0.004:
            problems.append(
                "lowest geometry floats %.4f m above the origin plane" % lo[1])
        for t in range(self.tri_count):
            i0, i1, i2 = self.idx[t * 3:t * 3 + 3]
            a = self.pos[i0 * 3:i0 * 3 + 3]
            b = self.pos[i1 * 3:i1 * 3 + 3]
            c = self.pos[i2 * 3:i2 * 3 + 3]
            n = _cross(_sub(b, a), _sub(c, a))
            area = 0.5 * math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2)
            if area < 1e-9:
                problems.append("degenerate triangle at index %d" % t)
                break
        return problems


# =========================================================================
# 3. GLB WRITER
# =========================================================================

_GLB_MAGIC = 0x46546C67
_CHUNK_JSON = 0x4E4F534A
_CHUNK_BIN = 0x004E4942


def _pad4(buf, filler=b"\x00"):
    while len(buf) % 4:
        buf += filler
    return buf


def write_glb(path, mesh, wall_mounted=False):
    """Write `mesh` as a self-contained .glb with the palette atlas embedded.

    Returns a dict of stats for the build log.
    """
    problems = mesh.check(require_floor=not wall_mounted)
    if problems:
        raise ValueError("%s: %s" % (mesh.name, "; ".join(problems)))

    pos_b = struct.pack("<%df" % len(mesh.pos), *mesh.pos)
    nrm_b = struct.pack("<%df" % len(mesh.nrm), *mesh.nrm)
    uv_b = struct.pack("<%df" % len(mesh.uv), *mesh.uv)
    idx_b = struct.pack("<%dI" % len(mesh.idx), *mesh.idx)
    png_b = atlas_png_bytes()

    blob = b""
    views = []
    for data, target in ((pos_b, 34962), (nrm_b, 34962), (uv_b, 34962),
                         (idx_b, 34963), (png_b, None)):
        blob = _pad4(blob)
        view = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)}
        if target is not None:
            view["target"] = target
        views.append(view)
        blob += data
    blob = _pad4(blob)

    lo, hi = mesh.bounds()
    n_vert = mesh.vert_count

    gltf = {
        "asset": {
            "version": "2.0",
            "generator": "museum-liminal tools/lowpoly (flat-shaded, "
                         "palette-atlas, no Blender)",
        },
        "scene": 0,
        "scenes": [{"name": mesh.name, "nodes": [0]}],
        "nodes": [{"name": mesh.name, "mesh": 0}],
        "meshes": [{
            "name": mesh.name,
            "primitives": [{
                "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                "indices": 3,
                "material": 0,
                "mode": 4,
            }],
        }],
        "materials": [{
            "name": "lowpoly_palette",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 0},
                "metallicFactor": 0.0,
                # Matches MaterialLib.apply_flat_style(): FLAT_STYLE forces
                # roughness 0.92 on every procedural material, and an imported
                # prop standing next to a code-built one must catch the light
                # the same way.
                "roughnessFactor": 0.92,
            },
            # Backface culling stays ON. If a face is wound inside out it will
            # show as a hole, which is a defect that gets caught in review --
            # doubleSided would hide the mistake instead of surfacing it.
            "doubleSided": False,
        }],
        "textures": [{"sampler": 0, "source": 0}],
        "samplers": [{
            # NEAREST magnification keeps a swatch a flat block of colour
            # instead of a gradient towards its neighbour; CLAMP_TO_EDGE stops
            # the outermost swatches wrapping around to the other side.
            "magFilter": 9728,
            "minFilter": 9987,
            "wrapS": 33071,
            "wrapT": 33071,
        }],
        "images": [{
            "name": "palette_atlas",
            "mimeType": "image/png",
            "bufferView": 4,
        }],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": n_vert,
             "type": "VEC3", "min": list(lo), "max": list(hi)},
            {"bufferView": 1, "componentType": 5126, "count": n_vert,
             "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": n_vert,
             "type": "VEC2"},
            {"bufferView": 3, "componentType": 5125, "count": len(mesh.idx),
             "type": "SCALAR"},
        ],
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }

    json_b = _pad4(json.dumps(gltf, separators=(",", ":")).encode("utf-8"),
                   b" ")
    total = 12 + 8 + len(json_b) + 8 + len(blob)
    out = struct.pack("<III", _GLB_MAGIC, 2, total)
    out += struct.pack("<II", len(json_b), _CHUNK_JSON) + json_b
    out += struct.pack("<II", len(blob), _CHUNK_BIN) + blob

    directory = os.path.dirname(os.path.abspath(path))
    if directory:
        os.makedirs(directory, exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(out)

    return {
        "name": mesh.name,
        "path": path,
        "tris": mesh.tri_count,
        "verts": n_vert,
        "bytes": len(out),
        "size": (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]),
        "wall_mounted": wall_mounted,
    }
