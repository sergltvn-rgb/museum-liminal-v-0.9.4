extends Node
## Selects a random affected exhibit and exposes its location to the incident
## systems. All gameplay puzzles now live exclusively in RiftTrialManager.

const STATE_ANOMALY := 2

# Feed indices into SecurityCameraTablet.CAMS -- 0-based, so index 4 is "CAM 05".
# Every exhibit names the feed that can actually SEE it. GameplayEnhancements
# only compares indices when it runs the confirmation scan, so a wrong index
# means the player completes "confirm the source with your own eyes" while the
# monitor shows a wall.
#
# Every index below is a measured sightline, not a guess: test_map_verification
# raycasts each mount to each exhibit's anchor in the built scene, and the
# clearances quoted here were read off that same cast.
const CAM_WING_A_GRAVITY := 4  # (16.4, 3.0, -7.8) -- inside Gravity Wing A
const CAM_WING_B_TIME := 5     # (-11.8, 3.0, -16.4) -- inside Time Wing B
# (42.2, 2.9, 6.8) -- south-west corner of Mass Wing D, the only feed covering
# the wing, and now the only one it needs: Superheavy Sphere 13.92 m, Dense
# Ingot 5.31 m, Mass Pendulum 16.10 m, all clear. From the wing's other west
# corner, where this post used to hang, the imported superheavy_sphere collider
# stood across the line to the Mass Pendulum and stopped the ray 13.23 m short.
const CAM_WING_D_MASS := 10
# (33.6, 2.9, -30.8) -- south-east corner of Space Wing C, aimed back down the
# wing at (24, 1.0, -24). All three Wing C exhibits are clear from it: Portal
# Arch 14.14 m (the ray meets the arch's own imported mesh), Star Globe 15.52 m,
# Orrery 5.43 m. The post used to hang at (9.6, 2.9, -20.6) inside Time Wing B,
# on the wrong side of the solid wall at x=13, where it saw none of them -- Wing
# C has exactly one aperture, the 1.8 m doorway at z=-24, and no mount outside
# the wing threads it. The blast door is still on this feed, 21.7 m away and
# 17 deg off the optical axis.
const CAM_WING_C_SPACE := 6
const EXHIBITS := {
	"gravity_surge": [
		{"name":"EXHIBIT_FALLING_CUBE", "wing":"EXHIBIT_WING_A", "origin":Vector3(21.5,0,-4.5), "anchor":"Anomaly Anchor - Falling Cube Exhibit", "rule":"ascending", "scale":"large", "camera":CAM_WING_A_GRAVITY},
		{"name":"EXHIBIT_INVERSION_ROOM", "wing":"EXHIBIT_WING_A", "origin":Vector3(28,0,-4.5), "anchor":"Anomaly Anchor - Inversion Room Exhibit", "rule":"descending", "scale":"small", "camera":CAM_WING_A_GRAVITY},
		{"name":"EXHIBIT_LEVITATING_COLUMN", "wing":"EXHIBIT_WING_A", "origin":Vector3(35.5,0,-4.5), "anchor":"Anomaly Anchor - Levitating Column Exhibit", "rule":"outside", "scale":"large", "camera":CAM_WING_A_GRAVITY},
	],
	"temporal_drift": [
		{"name":"EXHIBIT_BROKEN_CLOCK", "wing":"EXHIBIT_WING_B", "origin":Vector3(-8,0,-27.5), "anchor":"Anomaly Anchor - Broken Clock Exhibit", "rule":"ascending", "scale":"small", "camera":CAM_WING_B_TIME},
		{"name":"EXHIBIT_FROZEN_DROP", "wing":"EXHIBIT_WING_B", "origin":Vector3(0,0,-27.5), "anchor":"Anomaly Anchor - Frozen Drop Exhibit", "rule":"odd_even", "scale":"small", "camera":CAM_WING_B_TIME},
		{"name":"EXHIBIT_TIME_LOOP", "wing":"EXHIBIT_WING_B", "origin":Vector3(8,0,-27.5), "anchor":"Anomaly Anchor - Time Loop Exhibit", "rule":"descending", "scale":"normal", "camera":CAM_WING_B_TIME},
	],
	"void_rift": [
		{"name":"EXHIBIT_PORTAL_ARCH", "wing":"EXHIBIT_WING_C", "origin":Vector3(24,0,-20.5), "anchor":"Anomaly Anchor - Portal Arch Exhibit", "rule":"outside", "scale":"normal", "camera":CAM_WING_C_SPACE},
		{"name":"EXHIBIT_STAR_GLOBE", "wing":"EXHIBIT_WING_C", "origin":Vector3(18.5,0,-27.5), "anchor":"Anomaly Anchor - Star Globe Exhibit", "rule":"ascending", "scale":"large", "camera":CAM_WING_C_SPACE},
		{"name":"EXHIBIT_ORRERY", "wing":"EXHIBIT_WING_C", "origin":Vector3(29.5,0,-27.5), "anchor":"Anomaly Anchor - Orrery Exhibit", "rule":"odd_even", "scale":"small", "camera":CAM_WING_C_SPACE},
	],
	"radiation_bloom": [
		{"name":"EXHIBIT_SUPERHEAVY_SPHERE", "wing":"EXHIBIT_WING_D", "origin":Vector3(52,0,-3), "anchor":"Anomaly Anchor - Superheavy Sphere Exhibit", "rule":"descending", "scale":"large", "camera":CAM_WING_D_MASS},
		{"name":"EXHIBIT_DENSE_INGOT", "wing":"EXHIBIT_WING_D", "origin":Vector3(46.5,0,4), "anchor":"Anomaly Anchor - Dense Ingot Exhibit", "rule":"ascending", "scale":"large", "camera":CAM_WING_D_MASS},
		{"name":"EXHIBIT_MASS_PENDULUM", "wing":"EXHIBIT_WING_D", "origin":Vector3(58,0,4), "anchor":"Anomaly Anchor - Mass Pendulum Exhibit", "rule":"odd_even", "scale":"normal", "camera":CAM_WING_D_MASS},
	],
}

var _game: Node
var _active_id := ""
var _exhibit: Dictionary = {}
var _last_exhibit := ""
# Cached anomaly anchor: get_incident_origin() is polled every frame while a
# device is carried, and resolving it means a find_child() over the whole map.
var _anchor: Node3D = null
var _anchor_key := ""

func _ready() -> void:
	add_to_group("exhibit_puzzle_controller")
	call_deferred("_initialize")

func _initialize() -> void:
	if is_inside_tree(): _game = get_parent().get_node_or_null("GameManager")

func _process(_delta: float) -> void:
	if _game == null: return
	var state := int(_game.get("_state"))
	var anomaly_id := str(_game.get("_anomaly_id"))
	if state == STATE_ANOMALY and anomaly_id != "" and anomaly_id != _active_id:
		prepare_incident(anomaly_id, int(_game.get("_night")))
	elif state != STATE_ANOMALY and _active_id != "":
		_clear_incident()

func prepare_incident(anomaly_id: String, night: int) -> void:
	_clear_incident()
	_active_id = anomaly_id
	_exhibit = _choose_exhibit(night)
	_last_exhibit = str(_exhibit.get("name", ""))
	if _game != null and _game.has_method("set_objective"):
		_game.set_objective("incident", Loc.fmt("OBJ_INCIDENT_EXHIBIT", [tr(_exhibit["name"]), tr(_exhibit["wing"])]), 30)

func _choose_exhibit(night: int) -> Dictionary:
	var candidates: Array = []
	for family in EXHIBITS.values():
		for entry in family:
			var wing := str(entry.get("wing", ""))
			var minimum_night := 3 if "EXHIBIT_WING_D" in wing else (2 if "EXHIBIT_WING_C" in wing else 1)
			if night >= minimum_night:
				# The feed comes from the entry, not from the wing. Deriving it per
				# wing assumed one camera covers a whole wing, which is how all
				# three Wing C exhibits ended up on a feed that faces a wall.
				candidates.append(entry.duplicate(true))
	var selected: Dictionary = candidates.pick_random()
	if candidates.size() > 1:
		while str(selected.get("name", "")) == _last_exhibit:
			selected = candidates.pick_random()
	return selected.duplicate(true)

func get_incident_origin() -> Vector3:
	var anchor_name:=str(_exhibit.get("anchor",""))
	# Search once per incident, but only while the cache holds a live node.
	# is_instance_valid(null) is false, so we retry both when the anchor was
	# never resolved (map not built yet) and when it has since been freed.
	if _anchor_key!=anchor_name or not is_instance_valid(_anchor):
		_anchor_key=anchor_name
		_anchor=_find_anchor(anchor_name)
	if _anchor!=null:return _anchor.global_position-Vector3(0,1.55,0)
	return _exhibit.get("origin",Vector3.ZERO) as Vector3

func _find_anchor(anchor_name:String) -> Node3D:
	if anchor_name=="":return null
	var museum:=get_tree().get_first_node_in_group("museum_map")
	if museum==null:return null
	var root:=museum.get_node_or_null("GeneratedMap")
	if root==null:return null
	return root.find_child(anchor_name,true,false) as Node3D
func get_incident_name() -> String: return tr(str(_exhibit.get("name", "EXHIBIT_UNKNOWN")))
func get_required_camera() -> int: return int(_exhibit.get("camera", -1))

func _clear_incident() -> void:
	if _game != null and _game.has_method("clear_objective"): _game.clear_objective("incident")
	_active_id = ""
	_exhibit.clear()
	_anchor = null
	_anchor_key = ""
