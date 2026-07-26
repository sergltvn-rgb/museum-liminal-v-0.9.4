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
# (-13.6, 3.0, 12.6) -- CAM 02, "Atrium — West". Not a measured sightline like
# the four above, and it does not need to be: (0, 1.0, 0) is this feed's own aim
# point, so the containment core is dead centre of its frame by construction.
const CAM_ATRIUM_CORE := 1
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

# --- Which exhibit an anomaly is allowed to possess --------------------------
#
# EXHIBITS is keyed by anomaly id, and _choose_exhibit() used to ignore the key:
# it flattened all four families into one pool and drew from it at random, so a
# GRAVITY SURGE ("objects losing weight") regularly ruptured the Broken Clock in
# Wing B — Time while the terminal readout beside it said otherwise. The family
# is now honoured.
#
# Only four of GameManager.ANOMALIES' ten ids have a family here. The other six
# -- echo_chamber, glass_bridge, mirror_maze, yellow_halls, scrap_run, ascent --
# have none, and none of their readouts claims a quantity (RESONANT ECHO, PHASE
# COLLAPSE, MIRROR RIFT, YELLOW LIMIT, ASSET SEIZURE, VERTICAL RIFT), so there is
# no exhibit for them to contradict. They keep drawing from the whole eligible
# pool; giving them families of their own would mean 18 new exhibits and 18 new
# catalogue rows.
#
# What is left is night gating. void_rift's family stands in Space Wing C, sealed
# behind a blast door until night 2; radiation_bloom's stands in Mass Wing D,
# sealed until night 3 -- and GameManager rolls any of the ten on any night.
# Routing the operator at a locked door would make the shift unwinnable, so those
# three (anomaly, night) combinations go to the containment core instead. The
# core is the one target that contradicts nothing: the prologue introduces it as
# what "keeps all four quantities in agreement", it stands in the atrium and is
# always reachable, and both of the strings below already exist in game.csv.

## The incident's home when its own wing is still sealed.
##
## Deliberately NOT a fifth entry in EXHIBITS: it is not a family the ordinary
## draw may pull from, it is the answer to "your wing is behind a blast door
## tonight". Keeping it out also keeps the suites that read EXHIBITS honest --
## test_incident_catalog counts twelve authored incidents, test_map_verification
## raycasts every one of their anchors from every camera mount.
##
## No "anchor", so get_incident_origin() returns "origin" verbatim: the
## containment dais at the centre of the atrium, which FirstMuseumMap builds
## around (0, 0, 0) together with the pedestal, the core sphere and the dome.
## "rule" and "scale" are carried for shape parity with the entries above;
## nothing in the shipping game reads either field.
const CORE_INCIDENT := {
	"name":"EXHIBIT_CONTAINMENT_CORE", "wing":"CAM_ROOM_ATRIUM", "origin":Vector3(0,0,0),
	"anchor":"", "rule":"outside", "scale":"normal", "camera":CAM_ATRIUM_CORE,
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
	_exhibit = _choose_exhibit(night, anomaly_id)
	_last_exhibit = str(_exhibit.get("name", ""))
	if _game != null and _game.has_method("set_objective"):
		_game.set_objective("incident", Loc.fmt("OBJ_INCIDENT_EXHIBIT", [tr(_exhibit["name"]), tr(_exhibit["wing"])]), 30)

## Pick the exhibit an incident possesses.
##
## `anomaly_id` is optional because two suites sample this function with a single
## argument to read the shipping exhibit -> camera table out of it, and that
## sampling has to keep seeing all twelve exhibits. Production always passes the
## id; omitting it means "no family, draw from everything", which is also what
## the six anomalies without a family get.
func _choose_exhibit(night: int, anomaly_id: String = "") -> Dictionary:
	var candidates: Array = []
	var own_family: Array = []
	for family_id in EXHIBITS:
		for entry in EXHIBITS[family_id]:
			var wing := str(entry.get("wing", ""))
			var minimum_night := 3 if "EXHIBIT_WING_D" in wing else (2 if "EXHIBIT_WING_C" in wing else 1)
			if night < minimum_night:
				continue
			# The feed comes from the entry, not from the wing. Deriving it per
			# wing assumed one camera covers a whole wing, which is how all
			# three Wing C exhibits ended up on a feed that faces a wall.
			var candidate: Dictionary = entry.duplicate(true)
			candidates.append(candidate)
			if family_id == anomaly_id:
				own_family.append(candidate)
	if not own_family.is_empty():
		# The anomaly names a quantity, and the wing that holds it is open.
		candidates = own_family
	elif EXHIBITS.has(anomaly_id):
		# It names a quantity, but every exhibit of that quantity is still behind
		# a blast door tonight. Anything else in the museum would contradict the
		# readout, so the rupture takes the core instead.
		return CORE_INCIDENT.duplicate(true)
	if candidates.is_empty():
		# Unreachable while Wings A and B open on night 1, and cheaper than the
		# alternative: pick_random() on an empty array returns null, which reaches
		# the objective line as a crash rather than as a wrong exhibit.
		return CORE_INCIDENT.duplicate(true)
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
