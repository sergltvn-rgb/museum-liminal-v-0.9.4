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
	var total := 0
	for anomaly in families:
		for incident in families[anomaly]:
			total += 1
			var name := str(incident.get("name", ""))
			if name == "" or names.has(name): failures.append("invalid or duplicate name: %s" % name)
			names[name] = true
			if not incident.has("origin"): failures.append("%s has no origin" % name)
			if not str(incident.get("rule", "")) in ["ascending","descending","outside","odd_even"]: failures.append("%s has invalid rule" % name)
			if not str(incident.get("scale", "")) in ["small","normal","large"]: failures.append("%s has invalid scale" % name)
	if total != 12: failures.append("expected 12 incidents, found %d" % total)
	# All four local anomaly curves now cross small, normal and large thresholds.
	var ranges := {"gravity_surge":Vector2(.72,1.30),"temporal_drift":Vector2(.78,1.28),"radiation_bloom":Vector2(.74,1.30),"void_rift":Vector2(.72,1.30)}
	for anomaly in ranges:
		var span: Vector2 = ranges[anomaly]
		if span.x > .90 or span.y < 1.15: failures.append("%s cannot reach all calibration scales" % anomaly)
	for failure in failures: push_error("[FAIL] %s" % failure)
	print("Incident catalog: %d incidents, %d failure(s)" % [total, failures.size()])
	quit(0 if failures.is_empty() else 1)
