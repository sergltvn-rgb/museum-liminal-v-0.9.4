"""Blender-authored low-poly .glb props for museum-liminal.

RUN IT LIKE THIS (no GUI, no add-on install, nothing to click):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/lowpoly/blender_build.py

WHY BLENDER AND NOT tools/lowpoly/glb.py
----------------------------------------
glb.py writes glTF by hand and is perfectly good at boxes, tapers and painted
detail quads. What it fundamentally cannot do is change topology: it has no
bevel and no inset, because both require edge/face adjacency that a
write-only triangle soup does not have.

Those two operations are exactly what separates "a box" from "an object":

  * BEVEL turns the silhouette edge of a monitor head or a PC tower into a
    1-segment chamfer. At low poly the silhouette IS the model -- a chamfered
    edge catches a different light value than the two faces it joins, so the
    shape reads as manufactured plastic instead of as a cube.
  * INSET carves the screen well into the bezel and the key field into the
    keyboard as real recessed geometry, so they self-shadow. Painting them on
    as flat quads (which is all glb.py can do) leaves them looking like
    stickers.

Everything else is shared with glb.py -- literally, by importing it. The
palette, the atlas layout, the UV lookup and the PNG bytes all come from that
module, so a Blender-authored prop and a glb.py-authored prop are guaranteed
to be the same 26 colours. glb.py is standard-library only, which is what
makes it importable from inside Blender's bundled Python.

HOUSE STYLE -- identical to glb.py, restated so this file stands alone
----------------------------------------------------------------------
1 unit = 1 metre. Origin on the FLOOR, centred in X and Z (wall-mounted models
are the documented exception; none in this batch). Forward is -Z. Flat shading
only. One material, one 128x128 palette texture, one draw call per model. No
normal maps, no metal, no emission; metallic 0 / roughness 0.92 so an imported
prop lights exactly like a MaterialLib.apply_flat_style() procedural one.
Budget: dressing < 60 tris, furniture < 400, large fixture < 1200.

COORDINATE SPACE -- READ THIS BEFORE EDITING ANY NUMBER
-------------------------------------------------------
Every coordinate written in this file is in GODOT/glTF space: +X right, +Y up,
-Z forward. Blender is Z-up, so V() converts on the way in:

    blender = (gx, -gz, gy)

which is the exact inverse of the exporter's export_yup conversion
(x, y, z)_blender -> (x, z, -y)_gltf. The map has determinant +1, so it
preserves handedness: a face wound counter-clockwise in Godot coordinates is
still counter-clockwise in Blender, and a rotation about Godot +X is the same
rotation about Blender +X. Net effect: the numbers here read the same way as
the numbers in build_props.py, and nothing in the pipeline flips.

BATCH 2 -- WATCHER OFFICE DESK SET
----------------------------------
The office audit found two monitors on one desk from two different pipelines:
an imported basic_pc_monitors (FirstMuseumMap.gd:2171, scale 0.5) and the
procedural monitor inside OfficeProps.build_workstation_computer
(OfficeProps.gd:1247), which is so oversized it reads as a fridge. Both get
deleted and replaced by this coherent set:

    lp_desk_monitor   0.52 m wide -- matches OfficeProps MONITOR_W exactly, so
                      the desk monitor and the wall bank are the same product
    lp_pc_tower       under-desk tower
    lp_keyboard       flat two-tier keyboard
"""

from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import glb  # noqa: E402  -- stdlib only, safe under Blender's Python

# tools/lowpoly/blender_build.py -> tools/lowpoly -> tools -> repository root.
REPO_ROOT = os.path.dirname(os.path.dirname(HERE))
OUT_DIR = os.path.join(REPO_ROOT, "models", "lowpoly")

SWATCH_NAMES = list(glb.SWATCHES.keys())


def V(g):
    """Godot/glTF (x, y, z) -> Blender (x, y, z). Also valid for directions."""
    return Vector((g[0], -g[2], g[1]))


def G(b):
    """Blender (x, y, z) -> Godot/glTF (x, y, z). Inverse of V()."""
    return (b[0], b[2], -b[1])


# Unit-cube face windings, counter-clockwise seen from outside, in Godot
# coordinates. Copied from glb.py where they were verified by cross product;
# they are the single most error-prone table in the whole toolchain.
_UNIT_FACES = {
    "px": ((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)),
    "nx": ((-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)),
    "py": ((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)),
    "ny": ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)),
    "pz": ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)),
    "nz": ((-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)),
}

# Panel local basis per facing axis, chosen so that u x v == the face normal.
_PANEL_BASIS = {
    "px": ((0, 0, -1), (0, 1, 0)),
    "nx": ((0, 0, 1), (0, 1, 0)),
    "py": ((1, 0, 0), (0, 0, -1)),
    "ny": ((1, 0, 0), (0, 0, 1)),
    "pz": ((1, 0, 0), (0, 1, 0)),
    "nz": ((-1, 0, 0), (0, 1, 0)),
}

_AXIS_NORMAL = {
    "px": (1, 0, 0), "nx": (-1, 0, 0),
    "py": (0, 1, 0), "ny": (0, -1, 0),
    "pz": (0, 0, 1), "nz": (0, 0, -1),
}


class Part:
    """A single prop under construction.

    Faces carry two custom integer layers:
      "sw"    swatch index + 1. Zero means "nobody tagged this face", which is
              always a bug -- bevel and inset invent faces and it is very easy
              to forget them. finish() refuses to export if any face is 0.
      "solid" 1 for faces belonging to a closed manifold sub-solid. Those get
              recalc_face_normals() at the end, which makes inverted normals
              structurally impossible for boxes. Open shapes (tapers without
              caps, loose detail quads) stay at 0 and keep the winding they
              were authored with.
    """

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.sw = self.bm.faces.layers.int.new("sw")
        self.sl = self.bm.faces.layers.int.new("solid")
        self.tris = 0

    # ---- primitives ----------------------------------------------------

    def _tag(self, face, swatch, solid):
        face[self.sw] = glb.swatch_index(swatch) + 1
        face[self.sl] = solid
        face.smooth = False
        return face

    def _corner_solid(self, corners, swatch, faces=None, face_swatches=None):
        verts = {k: self.bm.verts.new(V(p)) for k, p in corners.items()}
        keys = list(_UNIT_FACES.keys()) if faces is None else list(faces)
        closed = 1 if len(keys) == 6 else 0
        out = []
        for key in keys:
            sw = (face_swatches or {}).get(key, swatch)
            f = self.bm.faces.new([verts[c] for c in _UNIT_FACES[key]])
            out.append(self._tag(f, sw, closed))
        return out

    def box(self, centre, size, swatch, faces=None, face_swatches=None):
        cx, cy, cz = centre
        hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        corners = {}
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    corners[(sx, sy, sz)] = (
                        cx + sx * hx, cy + sy * hy, cz + sz * hz)
        return self._corner_solid(corners, swatch, faces, face_swatches)

    def taper(self, base_centre, bottom_xz, top_xz, height, swatch,
              cap_top=True, cap_bottom=False, face_swatches=None):
        """Truncated pyramid: plinths that kick out, cornices that oversail."""
        cx, cy, cz = base_centre
        bx, bz = bottom_xz
        tx, tz = top_xz
        corners = {}
        for sx in (-1, 1):
            for sz in (-1, 1):
                corners[(sx, -1, sz)] = (
                    cx + sx * bx * 0.5, cy, cz + sz * bz * 0.5)
                corners[(sx, 1, sz)] = (
                    cx + sx * tx * 0.5, cy + height, cz + sz * tz * 0.5)
        keys = ["px", "nx", "pz", "nz"]
        if cap_top:
            keys.append("py")
        if cap_bottom:
            keys.append("ny")
        return self._corner_solid(corners, swatch, keys, face_swatches)

    def prism(self, base_centre, radius, height, sides, swatch,
              top_radius=None, cap_swatch=None, phase=0.0):
        """N-sided flat-shaded prism or frustum standing on `base_centre`.

        The shape box() and taper() cannot express, and the one the containment
        core is almost entirely made of: shield drums, bolted flanges, cage
        belts, pipe collars. `sides` stays in the 8-12 range for exactly the
        reason CylinderMesh is banned -- past 16 it stops reading as low-poly,
        and 12 already costs 44 triangles.

        Both caps are always emitted and never optional. That keeps every prism
        a closed manifold, which is what lets finish() run
        recalc_face_normals() over it: winding an n-gon ring by hand is the
        single easiest way to ship a model that renders inside out, and the
        20 triangles a hidden 12-gon cap costs are worth not having that class
        of bug at all.

        base_centre is on the AXIS at the BOTTOM face, in Godot coordinates, so
        a drum sitting on a deck at y = 0.24 is written with cy = 0.24 rather
        than as a centre plus half a height.
        """
        cx, cy, cz = base_centre
        rt = radius if top_radius is None else top_radius
        cap_swatch = cap_swatch or swatch
        bottom = []
        top = []
        for i in range(sides):
            a = phase + 2.0 * math.pi * float(i) / float(sides)
            bottom.append(self.bm.verts.new(V((
                cx + radius * math.cos(a), cy, cz + radius * math.sin(a)))))
            top.append(self.bm.verts.new(V((
                cx + rt * math.cos(a), cy + height,
                cz + rt * math.sin(a)))))
        out = []
        for i in range(sides):
            j = (i + 1) % sides
            f = self.bm.faces.new([bottom[i], top[i], top[j], bottom[j]])
            out.append(self._tag(f, swatch, 1))
        out.append(self._tag(self.bm.faces.new(list(reversed(top))),
                             cap_swatch, 1))
        out.append(self._tag(self.bm.faces.new(list(bottom)), cap_swatch, 1))
        return out

    def panel(self, centre, size, swatch, axis="pz"):
        """One quad. Painted detail: vents, labels, grime, screen sheen."""
        u = Vector(_PANEL_BASIS[axis][0]) * (size[0] * 0.5)
        v = Vector(_PANEL_BASIS[axis][1]) * (size[1] * 0.5)
        c = Vector(centre)
        pts = [c - u - v, c + u - v, c + u + v, c - u + v]
        f = self.bm.faces.new([self.bm.verts.new(V(p)) for p in pts])
        return [self._tag(f, swatch, 0)]

    # ---- topology operations, the reason this file exists ---------------

    def bevel(self, faces, offset, swatch, segments=1):
        """Chamfer the perimeter of the given faces. Returns the new faces."""
        faces = list(faces)
        if not faces:
            print("BEVEL_NO_TARGET", self.name, offset)
            return []
        edges = []
        seen = set()
        for f in faces:
            for e in f.edges:
                if e not in seen:
                    seen.add(e)
                    edges.append(e)
        try:
            res = bmesh.ops.bevel(
                self.bm, geom=edges, offset=offset, offset_type="OFFSET",
                segments=segments, profile=0.5, affect="EDGES",
                clamp_overlap=False)
        except TypeError as exc:  # a kwarg was renamed in this Blender
            print("BEVEL_SKIPPED", self.name, exc)
            return []
        made = res.get("faces", [])
        for f in made:
            self._tag(f, swatch, 1)
        print("BEVEL", self.name, "offset", offset, "edges", len(edges),
              "in", len(faces), "out", len(made))
        return made

    def inset(self, faces, thickness, depth, side_swatch, floor_swatch):
        """Carve a recess. The passed faces survive as the recessed floor."""
        faces = list(faces)
        res = bmesh.ops.inset_individual(
            self.bm, faces=faces, thickness=thickness, depth=depth,
            use_even_offset=True)
        sides = res.get("faces", [])
        for f in sides:
            self._tag(f, side_swatch, 1)
        for f in faces:
            self._tag(f, floor_swatch, 1)
        print("INSET", self.name, "in", len(faces), "sides", len(sides))
        return faces

    # ---- selection helpers ---------------------------------------------

    def mark_faces(self):
        return set(self.bm.faces)

    def mark_verts(self):
        return set(self.bm.verts)

    def new_faces(self, mark):
        return [f for f in self.bm.faces if f not in mark]

    def facing(self, faces, axis, tol=0.02, expect=1):
        """Pick faces whose normal points along a Godot axis key.

        bmesh does NOT compute a face normal when a face is created, and it
        does not refresh them after bevel or inset either. Without the
        normal_update() below every face reads as a zero-length vector, this
        function silently returns nothing, and bevel/inset become no-ops that
        leave a plain box behind. That failure is invisible in the export --
        the only symptom is a suspiciously low face count -- so `expect` turns
        it into a hard error instead.
        """
        self.bm.normal_update()
        d = V(_AXIS_NORMAL[axis]).normalized()
        out = []
        for f in faces:
            if f.normal.length < 1e-9:
                continue
            if f.normal.normalized().dot(d) > 1.0 - tol:
                out.append(f)
        if expect is not None and len(out) != expect:
            raise SystemExit(
                "%s: facing(%s) matched %d face(s), expected %d"
                % (self.name, axis, len(out), expect))
        return out

    def swing(self, mark_verts, angle_rad):
        """Rotate everything built since mark_verts about the model's Y axis.

        `angle_rad` is the SAME compass angle the props libraries use for
        radial placement, so a part authored pointing along +X ends up
        pointing along dir = (cos a, 0, sin a) -- write the angle straight out
        of AtriumProps and it lands where AtriumProps put it.

        THE MINUS SIGN IS NOT A TYPO. Godot's own rotation about +Y sends +X to
        (cos, 0, -sin), i.e. the other way round from that dir convention, and
        V() maps Godot +Y onto Blender +Z while preserving handedness, so the
        matrix is a Blender Z rotation by minus the angle. Drop the sign and
        the eight core ribs mirror off the TAU*i/8 + PI/8 spokes that keep the
        four cardinal sightlines through the cage open -- an invariant, and one
        that a triangle count can never catch.

        The pivot is the model's own axis, which is where every radial part in
        this pipeline turns about anyway.
        """
        verts = [v for v in self.bm.verts if v not in mark_verts]
        if not verts:
            return
        bmesh.ops.transform(
            self.bm, matrix=Matrix.Rotation(-angle_rad, 4, "Z"), verts=verts)

    def pitch(self, mark_verts, pivot, degrees):
        """Rotate everything built since mark_verts about the Godot X axis.

        Positive degrees tips the top away from the camera (towards +Z), which
        is how a desk monitor leans back.
        """
        verts = [v for v in self.bm.verts if v not in mark_verts]
        if not verts:
            return
        p = V(pivot)
        mat = (Matrix.Translation(p)
               @ Matrix.Rotation(math.radians(degrees), 4, "X")
               @ Matrix.Translation(-p))
        bmesh.ops.transform(self.bm, matrix=mat, verts=verts)

    # ---- output ---------------------------------------------------------

    def finish(self, material):
        bm = self.bm

        solids = [f for f in bm.faces if f[self.sl] == 1]
        if solids:
            bmesh.ops.recalc_face_normals(bm, faces=solids)

        untagged = [f for f in bm.faces if f[self.sw] <= 0]
        if untagged:
            raise SystemExit(
                "%s: %d face(s) have no swatch. Every bevel/inset result must "
                "be tagged." % (self.name, len(untagged)))

        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            u, v = glb.uv_for(SWATCH_NAMES[f[self.sw] - 1])
            # V IS FLIPPED HERE ON PURPOSE. glb.uv_for returns glTF-space UVs,
            # where V runs downwards from the top-left corner. Blender's V runs
            # upwards from the bottom-left, and the exporter writes 1-v on the
            # way out. Passing the glTF value through unchanged therefore lands
            # every face in the blank lower half of the atlas, and the model
            # renders as flat untextured white -- geometry perfect, colour gone.
            # Pre-flipping here cancels the exporter's flip exactly.
            for loop in f.loops:
                loop[uv].uv = (u, 1.0 - v)
            f.smooth = False

        self.tris = sum(len(f.verts) - 2 for f in bm.faces)
        self.quads = len(bm.faces)

        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        self.bm = None

        for p in me.polygons:
            p.use_smooth = False
        me.materials.append(material)

        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)

        xs = [G(v.co)[0] for v in me.vertices]
        ys = [G(v.co)[1] for v in me.vertices]
        zs = [G(v.co)[2] for v in me.vertices]
        self.bounds = ((min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs)))
        return obj


# =========================================================================
# Material: one Principled BSDF sampling the shared palette atlas
# =========================================================================

def make_material():
    atlas_path = os.path.join(bpy.app.tempdir, "palette_atlas.png")
    with open(atlas_path, "wb") as fh:
        fh.write(glb.atlas_png_bytes())

    img = bpy.data.images.load(atlas_path)
    img.name = "palette_atlas"
    img.colorspace_settings.name = "sRGB"
    img.pack()  # keeps the original PNG bytes, so the atlas is byte-identical

    mat = bpy.data.materials.new("lowpoly_palette")
    mat.use_nodes = True
    mat.use_backface_culling = True  # -> glTF doubleSided false
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")

    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"     # -> glTF magFilter NEAREST
    tex.extension = "EXTEND"          # -> glTF wrap CLAMP_TO_EDGE
    tex.location = (-320.0, 0.0)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.92
    if "Emission Strength" in bsdf.inputs:
        bsdf.inputs["Emission Strength"].default_value = 0.0
    return mat


def export_glb(obj, path):
    for other in bpy.context.scene.objects:
        other.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    wanted = {
        "filepath": path,
        "export_format": "GLB",
        "use_selection": True,
        "export_apply": True,
        "export_yup": True,
        "export_normals": True,
        "export_tangents": False,
        "export_materials": "EXPORT",
        "export_image_format": "AUTO",
        "export_cameras": False,
        "export_lights": False,
        "export_extras": False,
        "export_animations": False,
        "export_skins": False,
        "export_morph": False,
    }
    # Blender renames exporter properties between releases. Filtering against
    # the operator's own RNA means a rename degrades to "that option keeps its
    # default" instead of crashing the whole build.
    allowed = {p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
    kwargs = {k: v for k, v in wanted.items() if k in allowed}
    dropped = sorted(set(wanted) - set(kwargs))
    if dropped:
        print("EXPORT_UNKNOWN_KWARGS", dropped)
    bpy.ops.export_scene.gltf(**kwargs)


# =========================================================================
# lp_desk_monitor -- 0.52 x 0.54 x 0.19 m, screen faces -Z
# =========================================================================
# 0.520 wide is not a round number picked by eye: OfficeProps.MONITOR_W is
# 0.52, so this desk monitor is visibly the same product as the panels in the
# wall bank behind it. That shared measurement is what the old desk was
# missing -- an imported panel at scale 0.5 next to a procedural CRT the size
# of a fridge.
def build_desk_monitor(material):
    p = Part("lp_desk_monitor")

    # Moulded foot: bottom 0.300 x 0.190 kicking in to 0.256 x 0.156.
    p.taper((0.0, 0.0, 0.0), (0.300, 0.190), (0.256, 0.156), 0.022,
            "carcass_dark", cap_top=True, cap_bottom=False)

    # Stalk, also tapered so it does not read as a stick.
    p.taper((0.0, 0.022, 0.0), (0.076, 0.062), (0.052, 0.044), 0.176,
            "carcass", cap_top=False, cap_bottom=False)

    head_v = p.mark_verts()
    head_f = p.mark_faces()

    # Head: 0.520 x 0.340 x 0.070, bottom edge sitting on the stalk top.
    p.box((0.0, 0.368, 0.0), (0.520, 0.340, 0.070), "carcass",
          face_swatches={"nz": "carcass_dark", "py": "carcass_side",
                         "pz": "carcass_side"})

    body = p.new_faces(head_f)
    p.bevel(p.facing(body, "nz"), 0.008, "carcass_side")   # bezel chamfer
    body = p.new_faces(head_f)
    p.bevel(p.facing(body, "pz"), 0.016, "carcass_side")   # tapered back shell

    # Screen well: a real recess, 7 mm deep, so the bezel self-shadows.
    body = p.new_faces(head_f)
    p.inset(p.facing(body, "nz"), 0.030, -0.007, "shadow", "glass_dead")

    # Screen surface now sits at z = -0.028. Everything below is 0.5-1 mm proud
    # of whatever it lies on, which is the whole margin against z-fighting.
    p.panel((-0.150, 0.372, -0.0290), (0.026, 0.210), "glass_sheen", "nz")
    p.panel((-0.180, 0.221, -0.0355), (0.070, 0.010), "label", "nz")
    p.panel((0.190, 0.221, -0.0355), (0.012, 0.008), "tag", "nz")

    # Tip the head back 7 degrees about the stalk top. Done last so the bevel,
    # the inset walls and the painted detail all travel with it.
    p.pitch(head_v, (0.0, 0.198, 0.0), 7.0)

    return p, p.finish(material)


# =========================================================================
# lp_pc_tower -- 0.19 x 0.43 x 0.44 m, front faces -Z
# =========================================================================
def build_pc_tower(material):
    p = Part("lp_pc_tower")

    # Recessed foot: the body oversails it, so the tower does not look welded
    # to the floor.
    p.taper((0.0, 0.0, 0.0), (0.166, 0.404), (0.190, 0.436), 0.018,
            "plinth", cap_top=False, cap_bottom=False)

    body_f = p.mark_faces()
    p.box((0.0, 0.222, 0.0), (0.190, 0.408, 0.440), "carcass",
          face_swatches={"nz": "carcass_dark", "px": "carcass_side",
                         "nx": "carcass_side", "py": "top_cap"})

    body = p.new_faces(body_f)
    p.bevel(p.facing(body, "nz"), 0.010, "carcass_side")

    # Front face plane is z = -0.220. Detail sits 0.5 mm proud at -0.2205,
    # second-layer detail at -0.2212.
    p.panel((0.0, 0.386, -0.2205), (0.150, 0.028), "door_light", "nz")
    p.panel((0.0, 0.348, -0.2205), (0.150, 0.022), "door_dark", "nz")
    p.panel((-0.048, 0.296, -0.2205), (0.052, 0.016), "label", "nz")
    p.panel((0.0, 0.150, -0.2205), (0.130, 0.100), "shadow", "nz")
    for y in (0.120, 0.150, 0.180):
        p.panel((0.0, y, -0.2212), (0.130, 0.006), "carcass_side", "nz")

    # Power button as real geometry, half-buried in the front face so the hard
    # point lights in this game throw a shadow off it.
    p.box((0.048, 0.296, -0.2235), (0.024, 0.024, 0.013), "handle")

    # Rear I/O shroud. Real geometry rather than a painted quad for two
    # reasons: the back of a tower genuinely stands proud where the connectors
    # are, and it balances the 7.5 mm the power button sticks out at the front
    # so the bounding box stays centred on the origin in Z.
    p.box((0.0, 0.140, 0.2250), (0.150, 0.120, 0.010), "carcass_side",
          face_swatches={"pz": "shadow"})
    p.panel((0.0, 0.330, 0.2205), (0.080, 0.080), "carcass_dark", "pz")

    # Asymmetric wear so the two sides are not mirror images.
    p.panel((0.0955, 0.240, 0.070), (0.190, 0.150), "grime", "px")
    p.panel((0.0, 0.4265, 0.060), (0.120, 0.190), "grime", "py")

    return p, p.finish(material)


# =========================================================================
# lp_keyboard -- 0.44 x 0.024 x 0.15 m, key field faces up, front at -Z
# =========================================================================
# Deliberately NOT tilted on flip-out feet. A 6 degree tilt lifts the back
# edge 15 mm off the desk, and "prop floating above the surface" is the single
# most-reported defect in this audit. Flat costs nothing at low poly.
def build_keyboard(material):
    p = Part("lp_keyboard")

    p.box((0.0, 0.006, 0.0), (0.440, 0.012, 0.150), "carcass_dark")

    plate_f = p.mark_faces()
    p.box((0.0, 0.018, 0.004), (0.404, 0.012, 0.120), "carcass")

    plate = p.new_faces(plate_f)
    p.bevel(p.facing(plate, "py"), 0.005, "carcass_side")

    # Key well: 3 mm recess, floor lands at y = 0.021.
    plate = p.new_faces(plate_f)
    p.inset(p.facing(plate, "py"), 0.010, -0.003, "carcass_dark", "shadow")

    # Key blocks painted on the well floor, 0.2 mm proud, none overlapping.
    p.panel((-0.055, 0.0212, -0.004), (0.250, 0.064), "door", "py")
    p.panel((0.135, 0.0212, -0.004), (0.090, 0.064), "door_dark", "py")
    p.panel((-0.055, 0.0212, 0.036), (0.120, 0.012), "door_light", "py")
    p.panel((0.150, 0.0212, 0.036), (0.030, 0.006), "tag", "py")

    return p, p.finish(material)


# =========================================================================
# BATCH 3 -- CENTRAL ATRIUM
# =========================================================================
# The atrium focus pass (shots/decor_audit/focus_atrium) showed that the two
# props a visitor physically stands closest to are still raw primitives:
#
#   * the rope barrier is 8 x (cylinder base + cylinder post + sphere cap), so
#     from 3 m it reads as eight black sticks pushed into the floor. There is
#     no cast base to sit on, no collar and no finial to catch a highlight;
#   * the reception counter is four stacked boxes whose fascia is a separate
#     slab standing 20 mm proud of the carcass, so at a grazing angle it shows
#     as a seam instead of as a reveal, and the stone top has no edge at all.
#
# Both get the batch-2 treatment: BEVEL for the silhouette, INSET for the
# reveal. Same palette, same one-material one-draw-call rule.


# =========================================================================
# lp_stanchion -- 0.34 x 0.95 x 0.34 m, rope eyes on +-Z
# =========================================================================
# Height is matched to the procedural post it replaces (base 0.05 + post 0.95
# measured from the dais) so AtriumProps.build_rope_barrier can keep its rope
# catenary maths untouched: the beams still span between the same two points.
def build_stanchion(material):
    p = Part("lp_stanchion")

    # Cast base in two kicks. One taper reads as a cone; two read as a casting
    # that was moulded, which is the whole difference at this size.
    p.taper((0.0, 0.0, 0.0), (0.340, 0.340), (0.300, 0.300), 0.030,
            "plinth", cap_top=False, cap_bottom=False)
    p.taper((0.0, 0.030, 0.0), (0.300, 0.300), (0.220, 0.220), 0.048,
            "carcass_dark", cap_top=True, cap_bottom=False)

    # Post, tapered so it does not read as a length of pipe.
    p.taper((0.0, 0.078, 0.0), (0.070, 0.070), (0.050, 0.050), 0.742,
            "carcass", cap_top=False, cap_bottom=False)

    # Collar under the head: the shadow line that separates post from finial.
    p.box((0.0, 0.8385, 0.0), (0.088, 0.037, 0.088), "handle_dark",
          face_swatches={"py": "handle"})

    # Brass finial. Bevelling all twelve edges of a cube is the cheapest way
    # to get something that reads as turned metal instead of as a die.
    finial = p.box((0.0, 0.902, 0.0), (0.090, 0.090, 0.090), "lock")
    p.bevel(finial, 0.016, "lock")

    # One rope eye per side. Two, not one: a single eye would push the bounding
    # box off centre in Z, and a stanchion in the middle of a run genuinely
    # carries rope on both sides.
    for z in (-0.0575, 0.0575):
        p.box((0.0, 0.868, z), (0.030, 0.046, 0.025), "handle_dark")

    return p, p.finish(material)


# =========================================================================
# lp_reception_counter -- 3.92 x 1.10 x 1.24 m, public side faces -Z
# =========================================================================
# 3.920 x 1.100 is the AABB of the procedural "Counter Top", and 3.300 x 0.590
# is the procedural "Counter Fascia" -- reproduced here as the INSET recess, so
# the reveal is carved into the carcass instead of floating in front of it.
#
# TOTAL HEIGHT IS 1.100 AND THAT NUMBER IS LOAD-BEARING. The log book, keycard,
# monitors and task lamp in build_reception_desk are all positioned against a
# worktop at y = 1.10. Ship this model 45 mm shorter and every one of them
# floats -- which is the single most-reported defect in this whole audit.
# The return wing stays procedural; this model is the main run only.
def build_reception_counter(material):
    p = Part("lp_reception_counter")

    # Recessed kickplate. The carcass oversails it by 80 mm, which is what
    # stops the counter looking welded to the floor.
    p.box((0.0, 0.055, 0.100), (3.440, 0.110, 0.900), "shadow")

    body_f = p.mark_faces()
    p.box((0.0, 0.555, 0.100), (3.600, 0.890, 1.000), "wood",
          face_swatches={"px": "wood_dark", "nx": "wood_dark",
                         "pz": "wood_dark", "py": "wood_dark"})

    body = p.new_faces(body_f)
    p.bevel(p.facing(body, "nz"), 0.018, "wood_light")

    # The fascia, as a real 14 mm recess that self-shadows.
    #
    # Swatch order here matters and I got it backwards the first time: the
    # RECESS FLOOR must be the dark one and the reveal WALLS the light one.
    # Shipped the other way round, the 3.30 x 0.59 recess lit up as a pale
    # band straight across the counter front and the whole thing read as a
    # striped box instead of one solid mass. Dark floor + light reveal is what
    # makes the eye read "panel set into timber" rather than "stripe painted
    # on timber".
    body = p.new_faces(body_f)
    p.inset(p.facing(body, "nz"), 0.150, -0.014, "wood_light", "shadow")

    # Public face is z = -0.400; the recess floor sits at z = -0.386, so
    # painted detail goes 0.6 mm proud of it at -0.3866.
    p.panel((-1.180, 0.560, -0.3866), (0.900, 0.320), "wood_dark", "nz")
    p.panel((1.320, 0.400, -0.3866), (0.500, 0.220), "wood_dark", "nz")

    # Stone top. Lighter than the carcass on purpose: a single light band at
    # 1.1 m is what makes a reception desk legible from the entrance doorway,
    # 13 m away, which is the shot this whole model exists for.
    #
    # "door_light" is only light RELATIVE to the other door tones -- it is
    # tone(SLATE, -0.34) and under the atrium's cool, dim key it disappeared
    # into the carcass. "steel_bright" is the one swatch in the atlas that
    # actually reads as a lit horizontal at this range.
    top_f = p.mark_faces()
    p.box((0.0, 1.050, 0.0), (3.920, 0.100, 1.240), "door_dark",
          face_swatches={"py": "stone_pale"})
    top = p.new_faces(top_f)
    # Bevel the worktop in the SAME swatch as the face it cuts into. bevel()
    # consumes the face it is handed: shipped with "door_light" here it threw
    # away the pale py swatch set on the box above and the worktop came out
    # black in-engine even though the box declared a light top. Any bevel over
    # a deliberately-coloured face has to repeat that colour.
    p.bevel(p.facing(top, "py"), 0.014, "stone_pale")

    return p, p.finish(material)


# =========================================================================
# lp_museum_door_leaf -- 1.195 x 2.58 m ceremonial glazed leaf.
#
# Origin is the hinge axis at stylobate level; FirstMuseumMap places that pivot
# at y=0.36, so the 40 mm undercut lands the leaf bottom at world y=0.40. The
# model runs along +X and is reused for both sides by the two shut yaw values.
# Hardware is modelled on BOTH faces because the same door is read from the
# forecourt in daylight and from the lobby after entering.
# =========================================================================
def build_museum_door_leaf(material):
    p = Part("lp_museum_door_leaf")
    # At the 1.20 m half-opening this leaves a 5 mm allowance per leaf: a
    # believable 10 mm meeting joint instead of the visible 80 mm slot.
    w, h, t = 1.195, 2.58, 0.10

    body_mark = p.mark_faces()
    # The 2.58 m panel hangs 40 mm above its local hinge floor: its visible
    # top is therefore local y=2.62 and world y=2.98 on the porch stylobate.
    p.box((w * 0.5, 0.04 + h * 0.5, 0.0),
          (w, h, t), "wood",
          face_swatches={"px": "wood_dark", "nx": "wood_dark",
                         "py": "wood_light", "ny": "wood_dark"})
    body = p.new_faces(body_mark)
    p.bevel(body, 0.016, "wood_light")

    # Three real hinge knuckles touch y=0 and keep the asset origin measurable.
    for y in (0.0, 0.92, 2.18):
        p.prism((0.035, y, 0.0), 0.035, 0.18, 8, "hinge")

    # Recessed upper glazing and lower raised panel, on both public faces.
    for side in (-1.0, 1.0):
        z = side * 0.057
        p.box((0.58, 1.92, z), (0.76, 0.90, 0.014), "glass_dead")
        p.panel((0.44, 1.98, side * 0.065), (0.070, 0.68),
                "glass_sheen", "nz" if side < 0 else "pz")
        p.box((0.58, 0.88, side * 0.061), (0.72, 0.62, 0.022),
              "wood_light")
        p.box((0.58, 0.18, side * 0.062), (0.86, 0.22, 0.024), "lock")

        # Heavy applied stiles and rails: the shallow depth is enough to cast
        # a hard shadow without turning the silhouette into ornamental noise.
        for x in (0.13, 1.03):
            p.box((x, 1.50, side * 0.064), (0.12, 2.00, 0.028),
                  "wood_light")
        for y in (1.39, 2.43):
            p.box((0.58, y, side * 0.064), (0.90, 0.13, 0.028),
                  "wood_light")

        # Vertical museum pull at the meeting stile, with two stand-offs.
        # Keep the full two-sided hardware envelope at 240 mm. At 96 degrees
        # this preserves the audited 1.08 m open clearance through each half.
        handle_z = side * 0.100
        p.box((1.015, 1.55, handle_z), (0.045, 0.48, 0.040), "lock")
        for y in (1.36, 1.74):
            p.box((1.015, y, side * 0.080), (0.055, 0.050, 0.080), "lock")

    return p, p.finish(material)


# =========================================================================
# lp_blast_shutter -- 1.34 x 0.86 x 0.15 m curtain, public side faces -Z
# =========================================================================
# The south containment bay, jammed a third of the way down. The procedural
# version was five flat boxes painted alternately hazard and near-black, and
# from the gantry it read as a striped BILLBOARD parked beside the core: no
# depth, no shadow, just a sign. Two things fix that and neither is colour.
#
#   1. Every lath is TAPERED -- 140 mm deep at its bottom lip, 90 mm at its
#      top -- so it leans away from the eye and its own bottom edge throws a
#      hard line onto the lath below. Five leaning planes read as a shutter;
#      five coplanar rectangles read as paint on a board.
#   2. A recessed 7.5 mm shadow gap between laths. That is the seam a real
#      roller lath closes onto, and it is what carries the count.
#
# The alternating hazard stripe existed so the pattern survived greyscale.
# Geometry does that job better -- lean and gap read in any palette, and in
# the blackout too -- so hazard now appears exactly once, as a warning edge on
# the bottom rail, which is where a real blast door carries it anyway.
#
# TOTAL HEIGHT IS 0.860 AND THAT NUMBER IS LOAD-BEARING. The procedural slats
# spanned local y 1.60 .. 2.46 and the entrance eyeline is surveyed to pass
# 140 mm under the bottom rail. Ship this taller and the shot from the door
# loses the core behind it.
def build_blast_shutter(material):
    p = Part("lp_blast_shutter")

    # Bottom rail. Heavier than a lath because it is the edge that takes the
    # impact, and the only place hazard paint survives.
    p.box((0.0, 0.040, 0.0), (1.340, 0.080, 0.150), "carcass_dark",
          face_swatches={"ny": "shadow"})
    p.panel((0.0, 0.042, -0.0755), (1.200, 0.038), "tag", "nz")

    # Five laths on a 157.5 mm pitch: 150 mm of steel, 7.5 mm of shadow.
    for s in range(5):
        y0 = 0.080 + 0.1575 * s
        p.taper((0.0, y0, 0.0), (1.340, 0.140), (1.340, 0.090), 0.150,
                "carcass", cap_top=True, cap_bottom=True)
        if s < 4:
            p.box((0.0, y0 + 0.15375, 0.0), (1.300, 0.0075, 0.070), "shadow")

    return p, p.finish(material)


BUILDERS = (build_desk_monitor, build_pc_tower, build_keyboard,
            build_stanchion, build_reception_counter,
            build_museum_door_leaf, build_blast_shutter)

BUDGET = {
    "lp_desk_monitor": 400,
    "lp_pc_tower": 400,
    "lp_keyboard": 400,
    "lp_stanchion": 400,
    "lp_reception_counter": 600,
    "lp_museum_door_leaf": 650,
    "lp_blast_shutter": 400,
}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not os.path.isdir(OUT_DIR):
        os.makedirs(OUT_DIR)

    material = make_material()
    print("BLENDER", bpy.app.version_string)
    print("SWATCHES", len(SWATCH_NAMES))
    print("OUT_DIR", OUT_DIR)

    rows = []
    failures = []
    for builder in BUILDERS:
        part, obj = builder(material)
        path = os.path.join(OUT_DIR, part.name + ".glb")
        export_glb(obj, path)

        (lo, hi) = part.bounds
        size = (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
        nbytes = os.path.getsize(path) if os.path.exists(path) else 0

        # House-style assertions. These are the checks glb.Mesh.check() runs;
        # repeated here because Blender geometry never goes through it.
        if abs(lo[1]) > 1e-4:
            failures.append("%s: floor is at y=%.4f, must be 0"
                            % (part.name, lo[1]))
        if part.name == "lp_museum_door_leaf":
            # Deliberate exception: a swinging leaf is hinge-origin, not
            # footprint-centred. Its geometry must start on x=0.
            if abs(lo[0]) > 2e-3 or abs(hi[0] - 1.195) > 2e-3:
                failures.append("%s: hinge span is %.4f .. %.4f, expected 0 .. 1.195"
                                % (part.name, lo[0], hi[0]))
        elif abs(lo[0] + hi[0]) > 2e-3:
            failures.append("%s: not centred in X (%.4f .. %.4f)"
                            % (part.name, lo[0], hi[0]))
        if abs(lo[2] + hi[2]) > 2e-3:
            failures.append("%s: not centred in Z (%.4f .. %.4f)"
                            % (part.name, lo[2], hi[2]))
        if part.tris > BUDGET[part.name]:
            failures.append("%s: %d tris, over the %d budget"
                            % (part.name, part.tris, BUDGET[part.name]))
        if nbytes == 0:
            failures.append("%s: export produced no file" % part.name)

        rows.append((part.name, size, part.tris, part.quads, nbytes))
        bpy.data.objects.remove(obj, do_unlink=True)

    print("")
    print("%-18s %-24s %6s %6s %9s"
          % ("model", "bbox W x H x D (m)", "tris", "faces", "bytes"))
    print("-" * 68)
    for name, size, tris, quads, nbytes in rows:
        print("%-18s %-24s %6d %6d %9d"
              % (name, "%.3f x %.3f x %.3f" % size, tris, quads, nbytes))
    print("")

    if failures:
        for line in failures:
            print("FAIL", line)
        raise SystemExit(
            "blender_build: %d house-style violation(s)" % len(failures))

    print("BUILD_OK", len(rows), "models")


if __name__ == "__main__":
    main()