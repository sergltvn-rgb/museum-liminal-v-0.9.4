"""Dump the glTF material/texture wiring of every model in models/lowpoly.

Why this exists: a low-poly prop that renders pale in game is either (a) a
missing/ignored base colour texture, so the albedo falls back to white, or
(b) a palette that is genuinely too light. Guessing between the two costs a
full recapture cycle, so this reads the truth straight out of the .glb.

Run with the Windows python (PIL is needed to sample the atlas):
  "C:\\Users\\litvi\\AppData\\Local\\Programs\\Python\\Python312\\python.exe" tools\\lowpoly\\inspect_glb.py
"""

import glob
import io
import json
import os
import struct
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover - the report degrades, it does not die
    Image = None

JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def read_glb(path):
    """Return (gltf_json, binary_chunk) for a .glb file."""
    with open(path, "rb") as handle:
        data = handle.read()
    magic, _version, _length = struct.unpack("<III", data[:12])
    if magic != 0x46546C67:
        raise SystemExit("NOT_A_GLB %s" % path)
    offset = 12
    gltf = None
    binary = b""
    while offset + 8 <= len(data):
        chunk_len, chunk_type = struct.unpack("<II", data[offset:offset + 8])
        chunk = data[offset + 8:offset + 8 + chunk_len]
        if chunk_type == JSON_CHUNK:
            gltf = json.loads(chunk.decode("utf-8"))
        elif chunk_type == BIN_CHUNK:
            binary = chunk
        offset += 8 + chunk_len
    return gltf, binary


def image_bytes(gltf, binary, image):
    """Return the PNG bytes for a glTF image, embedded or side-car."""
    if "bufferView" in image:
        view = gltf["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        return binary[start:start + view["byteLength"]], "embedded"
    uri = image.get("uri", "")
    if uri.startswith("data:"):
        import base64

        return base64.b64decode(uri.split(",", 1)[1]), "data-uri"
    return None, uri


def report(path):
    gltf, binary = read_glb(path)
    name = os.path.basename(path)
    print("=== %s" % name)

    for index, material in enumerate(gltf.get("materials", [])):
        pbr = material.get("pbrMetallicRoughness", {})
        factor = pbr.get("baseColorFactor", [1, 1, 1, 1])
        texture = pbr.get("baseColorTexture")
        print("  material %d %-14s factor=%s metal=%s rough=%s doubleSided=%s" % (
            index,
            material.get("name", "?"),
            [round(v, 3) for v in factor],
            pbr.get("metallicFactor"),
            pbr.get("roughnessFactor"),
            material.get("doubleSided"),
        ))
        print("    baseColorTexture=%s emissive=%s alphaMode=%s" % (
            texture, material.get("emissiveFactor"), material.get("alphaMode")))

    for index, sampler in enumerate(gltf.get("samplers", [])):
        print("  sampler %d mag=%s min=%s wrapS=%s wrapT=%s" % (
            index, sampler.get("magFilter"), sampler.get("minFilter"),
            sampler.get("wrapS"), sampler.get("wrapT")))

    for index, image in enumerate(gltf.get("images", [])):
        blob, origin = image_bytes(gltf, binary, image)
        if blob is None:
            side_car = os.path.join(os.path.dirname(path), origin)
            exists = os.path.exists(side_car)
            print("  image %d uri=%s exists=%s" % (index, origin, exists))
            if exists:
                blob = open(side_car, "rb").read()
        else:
            print("  image %d %s bytes=%d mime=%s" % (
                index, origin, len(blob), image.get("mimeType")))
        if blob and Image is not None:
            atlas = Image.open(io.BytesIO(blob)).convert("RGB")
            print("    atlas %dx%d first swatches: %s" % (
                atlas.width, atlas.height,
                [atlas.getpixel((8 + 16 * i, 8)) for i in range(4)]))

    # UVs decide which swatch a face actually samples, so quote the range.
    mesh_uvs = []
    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            uv_index = primitive["attributes"].get("TEXCOORD_0")
            if uv_index is None:
                mesh_uvs.append("NO_TEXCOORD_0")
                continue
            accessor = gltf["accessors"][uv_index]
            mesh_uvs.append("uv count=%s min=%s max=%s" % (
                accessor.get("count"),
                [round(v, 4) for v in accessor.get("min", [])],
                [round(v, 4) for v in accessor.get("max", [])]))
    for line in mesh_uvs:
        print("  %s" % line)
    print("")


def main():
    targets = sys.argv[1:] or sorted(glob.glob(os.path.join("models", "lowpoly", "*.glb")))
    if not targets:
        print("NO_MODELS")
        return 1
    for path in targets:
        report(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
