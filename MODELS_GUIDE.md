# Model slots

## ПРАВИЛО: новые модели делаются в Blender и кладутся как .glb

Требование пользователя от 2026-08-06. **Если пользователь говорит «сделай модель» —
она собирается скриптом в Blender и экспортируется в `models/lowpoly/<имя>.glb`.**
Коробки из примитивов в GDScript моделью не считаются: они остаются только как
fallback на случай отсутствия файла.

- Сборщик кладётся в `tools/lowpoly/` тем же идиомом, что `blender_build.py`
  (`bb.Part`, один материал, один палитровый атлас 128x128, плоское затенение,
  metallic 0, roughness 0.92, forward -Z, фаски и inset вместо шейдерных трюков).
  Свежий пример — `tools/lowpoly/blender_cameras.py`.
- Запуск (Blender не прописан в PATH):
  `"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b -P tools\lowpoly\<script>.py`
- **Сразу после экспорта обязателен** `Godot --path . --headless --import`. Без него
  `ResourceLoader.exists()` вернёт false, `place()` отдаст `null`, нарисуется старый
  примитивный fallback — а тест останется зелёным. Доказательство, что модель
  реально встала, — изменившийся счётчик `MeshInstance3D` в
  `game/test_map_verification.gd`.
- Ни одна грань новой модели не должна лежать в одной плоскости с соседней:
  утапливать на 5-10 мм, иначе получится z-fighting, как на полу атриума.

`game/MapModels.gd` resolves a model name to `res://models/<name>.glb`, unless the name is
listed in `MODEL_PATHS` (`game/MapModels.gd:13`), which currently redirects `camera` and
`security_camera` to `res://models/camera.fbx`.

`MapModels.place()` returns `null` when `ResourceLoader.exists()` says the file is absent.
Every exhibit call site checks that return value and builds a procedural primitive instead,
so the map always builds. Drop a correctly named GLB into `models/` and it replaces the
fallback the next time the map is built — that is, on the next run, because the map is
generated at runtime (see README, "Как строится карта").

Note the naming rule: the slot name is the *filename*, not the exhibit title. Names are
case-sensitive and may contain spaces and Cyrillic — several shipped models do.

## Collision

`place()` calls `_ensure_collisions()` unless the name is in one of two lists:

- `NON_BLOCKING` — `camera`, `security_camera`, `vents`, `tactical_flashlight`,
  `modern_grey_stone_tile_texture`, `lp_key_cabinet`, `lp_stanchion`, `lp_security_camera`,
  `lp_camera_plate`. These get no collider at all. Read the comment block at
  `game/MapModels.gd:17` before adding anything here.
  `арка дверь` used to be on this list: its convex hull sealed the Atrium → Time Wing B
  doorway (2.18 m of hull across a 1.80 m opening), and the no-collider entry was the trade
  that kept the doorway navigable. In 0.9.4 the model was dropped from the map altogether,
  so the entry went with it.
  The four `lp_core_*` models are deliberately **not** listed. Their convex hulls stand in
  for the procedural core colliders that were removed with them, and exempting them would
  open a hole in the navmesh at the centre of the Atrium.
- `TRIMESH_COLLISION` — `portal_arch` only. It gets an exact concave collider because its
  convex hull would swallow a large slice of Space Wing C.

Everything else gets `create_convex_collision(true, true)` per mesh, and only if the imported
scene did not already contain a node whose name matches `*Collision*`.

## Exhibit slots (12) — fallback = procedural primitive

These twelve are the incident-bearing exhibits (`game/ExhibitPuzzleController.gd:33`), placed
by `_add_exhibit()` at `game/FirstMuseumMap.gd:1309`. Five have real models; seven are still
procedural.

| Slot file | Exhibit | Wing | Present? |
|---|---|---|---|
| `falling_cube.glb` | Falling Cube | Gravity Wing A | yes |
| `inversion_room.glb` | Inversion Room | Gravity Wing A | no — box fallback |
| `levitating_column.glb` | Levitating Column | Gravity Wing A | no — cylinder fallback |
| `broken_clock.glb` | Broken Clock | Time Wing B | yes |
| `frozen_drop.glb` | Frozen Drop | Time Wing B | yes |
| `time_loop.glb` | Time Loop | Time Wing B | no — torus fallback |
| `portal_arch.glb` | Portal Arch | Space Wing C | yes (trimesh collider) |
| `star_globe.glb` | Star Globe | Space Wing C | no — sphere fallback |
| `orrery.glb` | Orrery | Space Wing C | no — torus fallback |
| `superheavy_sphere.glb` | Superheavy Sphere | Mass Wing D | yes |
| `dense_ingot.glb` | Dense Ingot | Mass Wing D | no — box fallback |
| `mass_pendulum.glb` | Mass Pendulum | Mass Wing D | no — teardrop fallback |

## Decor slots (5) — fallback = procedural primitive

Queried the same way, but these are set dressing rather than incident exhibits. None of the
five is present.

| Slot file | Object | Call site |
|---|---|---|
| `balance_scale.glb` | Broken balance scale, Gravity Wing A | `FirstMuseumMap.gd:1609` |
| `great_hourglass.glb` | Great Hourglass, Time Wing B | `FirstMuseumMap.gd:1621` |
| `meteorite.glb` | Iron Meteorite, Gravity Wing A | `FirstMuseumMap.gd:1775` |
| `bronze_apple.glb` | The First Fall, Gravity Wing A | `FirstMuseumMap.gd:1780` |
| `sundial.glb` | Sundial, Time Wing B | `FirstMuseumMap.gd:1799` |

## Archive dressing (14) — no fallback

`_add_model_archive()` (`game/FirstMuseumMap.gd:1372`) places every supplied source model so
that nothing sits unused in the repository. These calls ignore the return value: if the file
disappears, the object simply does not appear, and nothing else changes.

`basic_pc_monitors`, `fancy_marble_coffee_table`, `wooden_bookcases_with_books`,
`elderly_woman_bust_on_pedestal`, `vents`, `tactical_flashlight`,
`уличная лампа`, `тумбочка`, `отсановка`, `dumpsters_glb`,
`gallery_bare_concrete_wall`, `modern_grey_stone_tile_texture`, `часы`, `наблюдатель`.

`лавочки.glb` was deleted in 0.9.4. It was authored as a back-to-back pair, so every one
of its placements had to find the far half by node name and hide it; the four atrium
benches are now built by `AtriumProps.build_rotunda_bench()` from the atrium palette.
Do not re-add the slot.

`арка дверь.glb` was dropped from the map in 0.9.4 at the owner's request: the archway
stood in the Atrium → Time Wing B doorway and read as a leftover prop. The file is still in
`models/`, but no call site asks for it, the slot is out of `NON_BLOCKING`, and its
`decor_shots.json` angle (`import_arch_door`) is gone — 132 shots became 131. Do not
re-place it.

## CCTV

The eleven CCTV posts are built by `FirstMuseumMap._camera()`, called from `_add_cameras()`
just above it. Since 0.9.4 the plate and the housing are Blender models --
`lp_camera_plate` and `lp_security_camera`, both from `tools/lowpoly/blender_cameras.py` --
placed through `MuseumModels.place()`, with the old primitive boxes kept inline as the
`null` fallback. The drop stem, the ball joint and the red LED stay procedural: the stem
length is computed per post from the soffit height, and the palette pipeline bakes no
emission.

`camera` / `security_camera` still resolve to `models/camera.fbx` through `MODEL_PATHS`, and
that 13.4 MB tripod is deliberately unused. A file named `security_camera.glb` would be
ignored, because `MODEL_PATHS` takes precedence over the `<name>.glb` convention -- which is
exactly why the new model is named `lp_security_camera`.

## Containment core (4) — fallback = procedural primitives

Since 0.9.4 the Atrium containment core is Blender geometry, built by
`tools/lowpoly/blender_core.py` and placed by `AtriumProps.build_containment_core()`.

| File | Tris | Placement |
| --- | --- | --- |
| `lp_core_base.glb` | 316 | one, at the core origin |
| `lp_core_column.glb` | 844 | one, on the base deck (y 0.24) |
| `lp_core_gantry.glb` | 146 | three, r 1.36, at 45° / 135° / 225° |
| `lp_core_plant.glb` | 282 | two, r 1.20, at 285° / 345° |

Yaw is `90.0 - <compass angle>`, because Godot's `Basis(Y, θ)` sends `+Z` to
`(sin θ, 0, cos θ)` while the outward radius is `(cos a, 0, sin a)`. Every call keeps its
primitive fallback inline, so a missing file still builds a core.

The 315° quarter is kept clear on purpose — CCTV camera 03 looks down that ray. That is why
the two coolant skids sit at 285° and 345° instead of the 292.5° / 337.5° the primitive
risers used: a 0.90 m skid at r 1.20 subtends about 41° and would have closed the window.

`Anomalous Core`, `Containment Dome`, `Core Beacon Lamp`, the four cable trunks and the
`Label3D` plaque stay procedural. Glow, a shader, emission, a length computed from the
ceiling height and live text are all things the flat palette pipeline cannot bake.

## Slots that no longer exist

Do not add these — nothing loads them. `models/README.md` still lists some of them and is
itself out of date.

`newton_statue.glb` (the atrium statue was removed in 0.2.3), `pendulum_bob.glb`,
`information_desk.glb`, `ticket_counter.glb`, `office_chair.glb`.

`office_chair.glb` is a special case: the file *is* in `models/`, but no call site asks for
it. See `CREDITS.md`.

## Placement conventions

- `place(parent, name, world_position, scale_factor, rotation_y_deg, pitch_x_deg)`.
- The model origin should rest on the floor (y = 0); exhibit call sites lift it to the
  pedestal top (+1.55 m) themselves.
- Forward is -Z. Godot's default euler order is YXZ, so `Vector3(pitch, yaw, 0)` yaws in
  world space and then pitches about the model's own right axis — what a wall bracket does.
  A **negative** pitch aims the lens at the floor; -14° reproduces the procedural CCTV
  fallback exactly.
- `scale_factor` is uniform; `1.0` assumes roughly human scale (≈1.5 m for a standing
  figure). Every archive placement overrides it, because the supplied sources disagree on
  units.
- Roll (Z) is preserved from the imported scene root; only pitch and yaw are overwritten.

## Free sources

Khronos glTF-Sample-Assets (CC-BY 4.0), direct GLB URL pattern:
`https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/<Name>/glTF-Binary/<Name>.glb`

Usable museum pieces: AntiqueCamera, ChronographWatch, DamagedHelmet, MosquitoInAmber,
ScatteringSkull, IridescenceAbalone, Lantern, SheenChair, GlamVelvetSofa, PotOfCoals, ToyCar,
WaterBottle, ABeautifulGame. Rename the file to a slot name above to mount it.

Other options for the empty slots: Smithsonian `3d.si.edu` (CC0 scans — column, meteorite,
sundial, celestial globe), Poly Pizza / Quaternius, Kenney kits, Sketchfab CC0 search.

Whatever you take, record its URL, author and license in `CREDITS.md` at the same time.

Note (Godot 4): KHR transmission/volume glass imports as matte; prefer opaque models or
replace glass materials after import.
