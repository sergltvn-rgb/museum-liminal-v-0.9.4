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
- The folder is intentionally empty for now; the procedural fallbacks are the
  default visual until real assets are added.
