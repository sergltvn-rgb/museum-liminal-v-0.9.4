# Models

This folder holds optional `.glb` 3D model files that replace the procedural
fallback primitives built by `game/FirstMuseumMap.gd`.

## How it works

`game/MapModels.gd` looks for `res://models/<model_name>.glb`. If the file
exists it is loaded, instantiated and placed at the object's world position.
If the file is **absent**, the map builder falls back to a procedural primitive
(cylinder, sphere, prism, capsule, box, or a small composite). Either way the
map builds and runs — drop a `.glb` in here and it automatically replaces the
fallback the next time the map is (re)built.

## Recognised model names

Drop a file with exactly this name (case-sensitive, `.glb` extension) to
replace that object:

| File name                  | Replaces                                  | Fallback shape            |
|----------------------------|-------------------------------------------|---------------------------|
| `newton_statue.glb`        | Statue of Newton in the atrium            | capsule body + sphere head|
| `pendulum_bob.glb`         | Gravity pendulum bob                      | sphere                    |
| `information_desk.glb`     | Atrium information desk                   | box                       |
| `ticket_counter.glb`       | Entrance ticket counter                   | box                       |
| `office_chair.glb`         | Chair behind the watcher desk             | cylinder composite        |
| `security_camera.glb`      | Security camera body + lens               | box + cylinder            |
| `falling_cube.glb`         | Gravity Wing exhibit                      | box (emissive)            |
| `inversion_room.glb`       | Gravity Wing exhibit                      | box                       |
| `levitating_column.glb`    | Gravity Wing exhibit                      | cylinder                  |
| `broken_clock.glb`         | Time Wing exhibit                         | box (emissive)            |
| `frozen_drop.glb`          | Time Wing exhibit                         | sphere (emissive)         |
| `time_loop.glb`            | Time Wing exhibit                         | torus ring (emissive)     |
| `portal_arch.glb`          | Space Wing C exhibit                      | prism arch + portal plane |
| `superheavy_sphere.glb`    | Mass Wing D exhibit                       | sphere                    |

## Placement conventions

- The model's origin should rest on the floor (y = 0); the script lifts it to
  the pedestal top (≈ y 1.55) automatically.
- Forward is -Z (standard Godot). `rotation_y_deg` in `MapModels.place()` is
  applied around Y if you need to turn a model.
- `scale_factor` is a uniform multiplier; default `1.0` assumes the model is
  already authored at roughly human scale (≈ 1.5 m tall for a standing figure).

## Notes

- Godot imports `.glb` automatically on editor open — no manual import step.
- `MapModels._resolve_path()` looks in three places, in order: the explicit
  `MODEL_PATHS` table, then `res://models/<name>.glb`, then
  `res://models/lowpoly/<name>.glb`. A purchased or hand-made model dropped in
  this folder therefore overrides a generated one with the same filename.

## models/lowpoly/ — generated assets

Build output of `tools/lowpoly/build_props.py`. Do not hand-edit the `.glb`
files; edit the builder and rebuild:

```
python tools/lowpoly/build_props.py
"<godot>" --headless --path . --import
```

The writer (`tools/lowpoly/glb.py`) is pure stdlib — no Blender, no PIL, no
glTF library. It emits real glTF 2.0 binary, so these files open in Blender,
Blockbench or any DCC if you ever want to hand-edit one; export back over the
same filename and the resolver picks it up with no code change.

| model | size w×h×d (m) | tris | mount |
| --- | --- | --- | --- |
| `lp_metal_locker` | 0.96 × 2.00 × 0.60 | 140 | floor |
| `lp_filing_cabinet` | 0.48 × 1.32 × 0.69 | 124 | floor |
| `lp_shelf_unit` | 1.00 × 1.90 × 0.42 | 178 | floor |
| `lp_key_cabinet` | 0.44 × 0.56 × 0.16 | 60 | wall |

House style, enforced by the builder:

- Flat shading only, no vertex sharing. One material, one 128×128 palette
  atlas, one draw call per model. Colours come from `game/props/Palette.gd`.
- No normal maps, no metal, no emission. `metallic 0 / roughness 0.92` to match
  `MaterialLib.apply_flat_style()`.
- Budget: small dressing < 60 tris, furniture < 400, large fixture < 1200. For
  scale, one smooth `CylinderMesh` is already 128 tris.
- `doubleSided: false` on purpose — an inverted face shows as a hole in review
  instead of being silently hidden.
- Wall-mounted models are the one exception to the floor-origin rule: their
  origin is the centre of the BACK face and the body extends towards -Z, so
  `place()` receives a point on the wall surface.

Preview them in a neutral studio with:

```
"<godot>" --path . --script res://game/test_lowpoly_preview.gd
```
