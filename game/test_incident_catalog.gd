extends SceneTree
## Validates every authored incident and future calibration reachability.

func _init() -> void:
	var failures: Array[String] = []
	var script := load("res://game/ExhibitPuzzleController.gd") as Script
	if script == null:
		push_error("Incident controller did not load"); quit(1); return
	var constants := script.get_script_constant_map()
	var families: Dictionary = constants.get("EXHIBITS", {})
	var names: Dictionary = {}
	var anchors: Dictionary = {}
	var total := 0
	for anomaly in families:
		for incident in families[anomaly]:
			total += 1
			var name := str(incident.get("name", ""))
			if name == "" or names.has(name): failures.append("invalid or duplicate name: %s" % name)
			names[name] = true
			if not incident.has("origin"): failures.append("%s has no origin" % name)
			# get_incident_origin() resolves "anchor" against the generated map with
			# find_child() and silently falls back to "origin" on a miss, so a typo
			# here parks the rift marker on stale coordinates with no error.
			# Only well-formed anchors enter the duplicate set. Recording the
			# malformed ones too meant two incidents each missing the key were
			# both "", and the second was reported as reusing anchor "" on top
			# of the real "has no map anchor" failure.
			var anchor := str(incident.get("anchor", ""))
			if not anchor.begins_with("Anomaly Anchor - "):
				failures.append("%s has no map anchor" % name)
			elif anchors.has(anchor):
				failures.append("%s reuses anchor %s" % [name, anchor])
			else:
				anchors[anchor] = true
			if not str(incident.get("rule", "")) in ["ascending","descending","outside","odd_even"]: failures.append("%s has invalid rule" % name)
			if not str(incident.get("scale", "")) in ["small","normal","large"]: failures.append("%s has invalid scale" % name)
	if total != 12: failures.append("expected 12 incidents, found %d" % total)
	# Calibration reachability. The previous version declared `ranges` itself and
	# then asserted against its own literals, so it passed no matter what the game
	# did. Read the shipping constants instead. Only the two thresholds below are
	# the test's own contract, because production defines no small/large cutoff.
	var small_max := 0.90
	var large_min := 1.15
	var enhancements := load("res://game/GameplayEnhancements.gd") as Script
	var scaler := load("res://game/PlayerScaleController.gd") as Script
	if enhancements == null or scaler == null:
		push_error("Player-scale sources did not load"); quit(1); return
	var ranges: Dictionary = enhancements.get_script_constant_map().get("ANOMALY_SCALE_SPAN", {})
	var clamps: Dictionary = scaler.get_script_constant_map()
	var clamp_min := float(clamps.get("SCALE_MIN", 0.58))
	var clamp_max := float(clamps.get("SCALE_MAX", 1.65))
	if ranges.is_empty(): failures.append("GameplayEnhancements exposes no ANOMALY_SCALE_SPAN")
	for anomaly in families:
		if not ranges.has(anomaly): failures.append("%s has no authored player-scale span" % anomaly)
	for anomaly in ranges:
		var span: Vector2 = ranges[anomaly]
		if span.x > small_max or span.y < large_min: failures.append("%s cannot reach all calibration scales" % anomaly)
		if span.x < clamp_min or span.y > clamp_max: failures.append("%s span is clipped by PlayerScaleController" % anomaly)
	# Wing gating: every night must offer at least one eligible exhibit, or
	# _choose_exhibit() calls pick_random() on an empty array.
	# Node.new() + set_script() rather than script.new(): `new` is only resolvable
	# on a class known at compile time, and calling it on a Script-typed value
	# fails with "Nonexistent function 'new' in base 'GDScript'".
	var controller := Node.new()
	controller.set_script(script)
	for night in [1, 2, 3]:
		var chosen: Variant = controller.call("_choose_exhibit", night)
		if typeof(chosen) != TYPE_DICTIONARY or (chosen as Dictionary).is_empty():
			failures.append("night %d has no eligible exhibit" % night)
	controller.free()
	for failure in failures: push_error("[FAIL] %s" % failure)
	print("Incident catalog: %d incidents, %d failure(s)" % [total, failures.size()])
	quit(0 if failures.is_empty() else 1)
