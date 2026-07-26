extends Node
## Changes perceived player size without scaling CharacterBody3D itself.

## Hard limits on the perceived-size multiplier. Anything an anomaly requests
## outside this window is silently clamped, so test_incident_catalog.gd checks
## the authored anomaly spans against these two values.
const SCALE_MIN := 0.58
const SCALE_MAX := 1.65

## Below this delta the remaining size change is invisible (0.0005 of the 1.8 m
## base height is under a millimetre, and under 0.006° of FOV), so _current
## snaps onto _target instead of crawling toward it forever.
const SCALE_EPSILON := 0.0005

var _player: CharacterBody3D
var _collision: CollisionShape3D
var _camera: Camera3D
var _flashlight: SpotLight3D
var _capsule: CapsuleShape3D
var _base_radius := 0.35
var _base_height := 1.8
var _base_camera_y := 1.65
var _base_light_y := 1.55
var _current := 1.0
var _target := 1.0
var _return_in := -1.0
# Latch: true once _current has landed exactly on _target AND the final
# _apply_scale() for that value has run. Starts false so the very first frame
# still writes the capsule, the collision offset and the camera FOV.
var _settled := false


func _ready() -> void:
	add_to_group("player_scale_controller")
	_player = get_parent() as CharacterBody3D
	if _player == null:
		return
	_collision = _player.get_node_or_null("Player Collision") as CollisionShape3D
	_camera = _player.get_node_or_null("Player Camera") as Camera3D
	_flashlight = _player.get_node_or_null("Player Camera/Player Flashlight") as SpotLight3D
	if _collision != null:
		_capsule = _collision.shape as CapsuleShape3D
	if _capsule != null:
		_base_radius = _capsule.radius
		_base_height = _capsule.height
	if _camera != null:
		_base_camera_y = _camera.position.y
	if _flashlight != null:
		_base_light_y = _flashlight.position.y


func _process(delta: float) -> void:
	if _player == null:
		return
	# Rewriting the capsule every frame forces the physics server to rebuild the
	# shape, so only do it while the size is actually moving. lerpf() approaches
	# asymptotically and never compares equal to _target, hence the epsilon; the
	# _settled latch guarantees the exact target value is still applied once.
	if not _settled:
		if absf(_target - _current) <= SCALE_EPSILON:
			_current = _target
			_settled = true
		else:
			_current = lerpf(_current, _target, clampf(delta * 3.2, 0.0, 1.0))
		_apply_scale(_current)
	if _return_in > 0.0:
		_return_in -= delta
		if _return_in <= 0.0:
			set_target(1.0)


func set_target(multiplier: float, duration := -1.0) -> void:
	var wanted := clampf(multiplier, SCALE_MIN, SCALE_MAX)
	if wanted != _target:
		_target = wanted
		# Restart the per-frame apply loop; _process() latches it again once
		# _current lands on the new target.
		_settled = false
	_return_in = duration


func pulse(multiplier: float, duration := 5.0) -> void:
	set_target(multiplier, duration)


func reset() -> void:
	set_target(1.0)


func get_scale_factor() -> float:
	return _current


func _apply_scale(factor: float) -> void:
	if _capsule != null:
		_capsule.radius = _base_radius * factor
		_capsule.height = _base_height * factor
	if _collision != null:
		_collision.position.y = _base_height * factor * 0.5
	if _camera != null:
		_camera.position.y = _base_camera_y * factor
		_camera.fov = lerpf(78.0, 66.0, inverse_lerp(SCALE_MIN, SCALE_MAX, factor))
	if _flashlight != null:
		# The flashlight is camera-mounted; keep its small local offset stable.
		_flashlight.position.y = _base_light_y
