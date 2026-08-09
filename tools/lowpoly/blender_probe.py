"""Probe the installed Blender: version, glTF exporter availability, Python.

Run:
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup --python tools/lowpoly/blender_probe.py
"""

import sys

import addon_utils
import bpy

print("BPY_VERSION", bpy.app.version_string)
print("PY_VERSION", sys.version.split()[0])

names = [m.__name__ for m in addon_utils.modules()]
gltf = [n for n in names if "gltf" in n.lower()]
print("GLTF_MODULES", gltf)

for name in gltf:
    default_on, loaded = addon_utils.check(name)
    print("STATE", name, "default=%s" % default_on, "loaded=%s" % loaded)
    if not loaded:
        try:
            addon_utils.enable(name, default_set=False, persistent=False)
            print("ENABLED", name)
        except Exception as exc:  # noqa: BLE001
            print("ENABLE_FAILED", name, exc)

print("HAS_EXPORT_GLTF", hasattr(bpy.ops.export_scene, "gltf"))

# Smoke test: build a 12-tri box, flat shade it, export a .glb to the temp dir.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_cube_add(size=1.0)
obj = bpy.context.active_object
obj.name = "probe_cube"
for poly in obj.data.polygons:
    poly.use_smooth = False
print("TRIS_BEFORE", len(obj.data.polygons))

out = bpy.app.tempdir.rstrip("\\/") + "/blender_probe.glb"
try:
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
    )
    import os

    print("EXPORT_OK", out, os.path.getsize(out))
except Exception as exc:  # noqa: BLE001
    print("EXPORT_FAILED", exc)

print("PROBE_DONE")
