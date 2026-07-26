class_name RiftTrialRegistry
extends RefCounted
## Central catalogue of every pocket-dimension trial. Splitting the former
## 900-line monolith into declarative scene descriptors lets GameManager,
## the tutorial layer and the localization pass share one source of truth.

## Ordered list. Each entry is a self-contained "scene" definition for a trial:
##   kind           – runtime match key used by RiftTrialManager
##   title_key      – localization key for the trial name
##   objective_key  – localization key of the first status line shown on entry
##   tutorial_key   – localization key of the one-shot micro hints (\n separated)
##   fail_tip_key   – localization key shown on the failure feedback panel
## All texts live in localization/game.csv; const cannot call tr(), so the
## lookup happens in the *_for() helpers below.
const TRIALS := [
	{
		"kind": "gravity_surge",
		"title_key": "TRIAL_GRAVITY_TITLE",
		"objective_key": "TRIAL_GRAVITY_OBJECTIVE",
		"tutorial_key": "TRIAL_GRAVITY_TUTORIAL",
		"fail_tip_key": "TRIAL_GRAVITY_FAILTIP",
	},
	{
		"kind": "temporal_drift",
		"title_key": "TRIAL_TIME_TITLE",
		"objective_key": "TRIAL_TIME_OBJECTIVE",
		"tutorial_key": "TRIAL_TIME_TUTORIAL",
		"fail_tip_key": "TRIAL_TIME_FAILTIP",
	},
	{
		"kind": "radiation_bloom",
		"title_key": "TRIAL_RADIATION_TITLE",
		"objective_key": "TRIAL_RADIATION_OBJECTIVE",
		"tutorial_key": "TRIAL_RADIATION_TUTORIAL",
		"fail_tip_key": "TRIAL_RADIATION_FAILTIP",
	},
	{
		"kind": "echo_chamber",
		"title_key": "TRIAL_ECHO_TITLE",
		"objective_key": "TRIAL_ECHO_OBJECTIVE",
		"tutorial_key": "TRIAL_ECHO_TUTORIAL",
		"fail_tip_key": "TRIAL_ECHO_FAILTIP",
	},
	{
		"kind": "glass_bridge",
		"title_key": "TRIAL_BRIDGE_TITLE",
		"objective_key": "TRIAL_BRIDGE_OBJECTIVE",
		"tutorial_key": "TRIAL_BRIDGE_TUTORIAL",
		"fail_tip_key": "TRIAL_BRIDGE_FAILTIP",
	},
	{
		"kind": "mirror_maze",
		"title_key": "TRIAL_MIRROR_TITLE",
		"objective_key": "TRIAL_MIRROR_OBJECTIVE",
		"tutorial_key": "TRIAL_MIRROR_TUTORIAL",
		"fail_tip_key": "TRIAL_MIRROR_FAILTIP",
	},
	{
		"kind": "yellow_halls",
		"title_key": "TRIAL_YELLOW_TITLE",
		"objective_key": "TRIAL_YELLOW_OBJECTIVE",
		"tutorial_key": "TRIAL_YELLOW_TUTORIAL",
		"fail_tip_key": "TRIAL_YELLOW_FAILTIP",
	},
	{
		"kind": "scrap_run",
		"title_key": "TRIAL_SCRAP_TITLE",
		"objective_key": "TRIAL_SCRAP_OBJECTIVE",
		"tutorial_key": "TRIAL_SCRAP_TUTORIAL",
		"fail_tip_key": "TRIAL_SCRAP_FAILTIP",
	},
	{
		"kind": "ascent",
		"title_key": "TRIAL_ASCENT_TITLE",
		"objective_key": "TRIAL_ASCENT_OBJECTIVE",
		"tutorial_key": "TRIAL_ASCENT_TUTORIAL",
		"fail_tip_key": "TRIAL_ASCENT_FAILTIP",
	},
	{
		"kind": "void_rift",
		"title_key": "TRIAL_VOID_TITLE",
		"objective_key": "TRIAL_VOID_OBJECTIVE",
		"tutorial_key": "TRIAL_VOID_TUTORIAL",
		"fail_tip_key": "TRIAL_VOID_FAILTIP",
	},
]

static func kinds() -> PackedStringArray:
	var result := PackedStringArray()
	for entry in TRIALS:
		result.append(String(entry["kind"]))
	return result

static func find(kind: String) -> Dictionary:
	for entry in TRIALS:
		if String(entry["kind"]) == kind:
			return entry
	return {}

## Static context cannot use Object.tr(), so translate through the server.
static func _translate(key: String) -> String:
	if key == "":
		return ""
	return String(TranslationServer.translate(key))

static func title_for(kind: String, _use_en := false) -> String:
	var entry := find(kind)
	if entry.is_empty():
		return kind
	return _translate(String(entry["title_key"]))

static func objective_for(kind: String, _use_en := false) -> String:
	var entry := find(kind)
	if entry.is_empty():
		return ""
	return _translate(String(entry["objective_key"]))

static func tutorial_for(kind: String, _use_en := false) -> PackedStringArray:
	var entry := find(kind)
	if entry.is_empty():
		return PackedStringArray()
	return _translate(String(entry["tutorial_key"])).split("\n", false)

static func fail_tip_for(kind: String, _use_en := false) -> String:
	var entry := find(kind)
	if entry.is_empty():
		return ""
	return _translate(String(entry["fail_tip_key"]))
