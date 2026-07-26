# Model slots

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
  `modern_grey_stone_tile_texture`, `арка дверь`. These get no collider at all. Read the
  comment block at `game/MapModels.gd:17` before adding anything here: the `арка дверь`
  entry is a deliberate trade that keeps the Atrium → Time Wing B doorway navigable for the
  Curator at the price of posts the player can walk through.
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

## Archive dressing (16) — no fallback

`_add_model_archive()` (`game/FirstMuseumMap.gd:1372`) places every supplied source model so
that nothing sits unused in the repository. These calls ignore the return value: if the file
disappears, the object simply does not appear, and nothing else changes.

`basic_pc_monitors`, `fancy_marble_coffee_table`, `wooden_bookcases_with_books`,
`elderly_woman_bust_on_pedestal`, `vents`, `tactical_flashlight`, `лавочки`,
`уличная лампа`, `арка дверь`, `тумбочка`, `отсановка`, `dumpsters_glb`,
`gallery_bare_concrete_wall`, `modern_grey_stone_tile_texture`, `часы`, `наблюдатель`.

## CCTV

`camera` / `security_camera` both resolve to `models/camera.fbx`. A file named
`security_camera.glb` would be ignored, because `MODEL_PATHS` takes precedence over the
`<name>.glb` convention. The procedural CCTV fallback lives in `FirstMuseumMap._camera()`
(`game/FirstMuseumMap.gd:593`), which explains why it is built from primitives rather than
from the FBX.

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
