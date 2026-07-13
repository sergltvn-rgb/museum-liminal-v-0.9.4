extends Node
## Changes perceived player size without scaling CharacterBody3D itself.

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
	_current = lerpf(_current, _target, clampf(delta * 3.2, 0.0, 1.0))
	_apply_scale(_current)
	if _return_in > 0.0:
		_return_in -= delta
		if _return_in <= 0.0:
			set_target(1.0)


func set_target(multiplier: float, duration := -1.0) -> void:
	_target = clampf(multiplier, 0.58, 1.65)
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
		_camera.fov = lerpf(78.0, 66.0, inverse_lerp(0.58, 1.65, factor))
	if _flashlight != null:
		# The flashlight is camera-mounted; keep its small local offset stable.
		_flashlight.position.y = _base_light_y
