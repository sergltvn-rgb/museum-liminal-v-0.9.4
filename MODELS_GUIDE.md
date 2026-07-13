# Model slots (res://models/<name>.glb)

Drop a GLB with the matching filename into `models/` and the map will use it
automatically instead of the procedural fallback (MapModels.place).

## Already in the project

| File | Exhibit |
|---|---|
| broken_clock.glb | Broken Clock (Time Wing B) |
| falling_cube.glb | Falling Cube (Gravity Wing A) |
| frozen_drop.glb | Frozen Drop (Time Wing B) |
| newton_statue.glb | Atrium statue — currently uses correctly scaled procedural fallback |
| office_chair.glb | Watcher Office |
| portal_arch.glb | Portal Arch (Space Wing C) |
| superheavy_sphere.glb | Superheavy Sphere (Mass Wing D) |

## Free slots (fallback = procedural primitive)

| File | Exhibit | Suggested free source |
|---|---|---|
| inversion_room.glb | Inversion Room, Wing A | Khronos: Cube-family / own model |
| levitating_column.glb | Levitating Column, Wing A | Smithsonian 3d.si.edu: column scan (CC0) |
| time_loop.glb | Time Loop, Wing B | Khronos: TorusKnot-like / own model |
| great_hourglass.glb | Great Hourglass, Wing B | Sketchfab CC0: "hourglass" |
| balance_scale.glb | Broken Scale, Wing A | Sketchfab CC0: "balance scale" |
| meteorite.glb | Iron Meteorite, Wing A | Smithsonian 3d.si.edu: meteorite scans (CC0) |
| bronze_apple.glb | The First Fall, Wing A | Poly Pizza / Quaternius: apple |
| sundial.glb | Sundial, Wing B | Smithsonian 3d.si.edu: sundial (CC0) |
| star_globe.glb | Star Globe, Wing C | Smithsonian: celestial globe (CC0) |
| orrery.glb | Orrery, Wing C | Sketchfab CC0: "orrery" |
| dense_ingot.glb | Dense Ingot, Wing D | Kenney / Poly Pizza: ingot |
| mass_pendulum.glb | Mass Pendulum, Wing D | Sketchfab CC0: "pendulum" |
| pendulum_bob.glb | Atrium pendulum | -- |
| information_desk.glb | Atrium desk | Kenney furniture kit |
| ticket_counter.glb | Entrance counter | Kenney furniture kit |

## Khronos glTF-Sample-Assets (CC-BY 4.0)

Direct GLB URL pattern:
`https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/<Name>/glTF-Binary/<Name>.glb`

Good museum pieces: AntiqueCamera, ChronographWatch, DamagedHelmet,
MosquitoInAmber, ScatteringSkull, IridescenceAbalone, Lantern, SheenChair,
GlamVelvetSofa, PotOfCoals, ToyCar, WaterBottle, ABeautifulGame (chess).
Rename the file to a slot name above to mount it as that exhibit.

Note (Godot 4): KHR transmission/volume glass imports as matte; prefer opaque
models or replace glass materials after import.
