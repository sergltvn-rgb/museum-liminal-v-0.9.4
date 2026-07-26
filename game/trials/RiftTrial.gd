class_name RiftTrial
extends Node
## Scene-backed definition shared by every pocket-dimension trial.
##
## Stage 3.2 — this was a facade, not a contract. Of its ten methods only four
## (build / process_trial / interact / cleanup) were ever called. localized_title(),
## objective(), tutorial_steps(), fail_tip() and secondary_action() had no call site
## anywhere in the repository, and reset_after_fall() relayed into
## "_reset_after_fall_legacy" — a method that has never existed here, so the first
## caller to wire it up would have taken a runtime crash. The four text helpers also
## read @export fields that not one of the ten trial scenes fills, so they could only
## ever return ""; those strings belong to RiftTrialRegistry, which stays the single
## source of truth for them.
##
## What survives is the contract RiftTrialManager really drives, in call order.
## `ctx` is always the manager.
##
##   _build(ctx)                  once, while the pocket world is assembled
##   _tick(ctx, delta)            physics step: movement, move_and_slide, ray casts
##   _tick_visuals(ctx, delta)    drawn frame: HUD text, materials, cosmetic timers
##   _on_interact(ctx, body)      "interact" pressed while `body` is in reach
##   _on_secondary(ctx, action)   "drop_item" / "radar_scan"; true if consumed
##   _on_fall(ctx)                player left the playable volume
##   _teardown(ctx)               trial closed, node about to be freed
##
## _tick and _tick_visuals are two hooks rather than one because Stage 3.6 split the
## manager's frame work: anything that moves a body or asks the physics server a
## question runs on the fixed step, everything cosmetic stays on the drawn frame.
##
## Every default body forwards to the manager's legacy dispatcher, so all ten trials
## keep running exactly as before. A trial migrates off that dispatcher by attaching
## a script that `extends RiftTrial` and overriding only the hooks it owns; the
## manager needs no edit, because it never calls anything but these seven names.
##
## `ctx` is deliberately untyped. RiftTrialManager has no class_name — giving it one
## would close a preload cycle, since the manager preloads the scenes that carry this
## script — so a `Node`-typed parameter could not resolve these calls at all. Untyped
## keeps them ordinary method calls instead of the stringly-typed manager.call("...")
## reflection this file used to be made of.

@export var kind: StringName
@export var title_key: StringName

func localized_title() -> String:
	if String(title_key) == "":
		return ""
	return tr(String(title_key))

func _build(ctx) -> void:
	ctx._build_trial_legacy(String(kind))

func _tick(ctx, delta: float) -> void:
	ctx._physics_trial_legacy(String(kind), delta)

func _tick_visuals(ctx, delta: float) -> void:
	ctx._visual_trial_legacy(String(kind), delta)

func _on_interact(ctx, body: StaticBody3D) -> void:
	ctx._interact_trial_legacy(body)

func _on_secondary(ctx, action: StringName) -> bool:
	return bool(ctx._secondary_action_legacy(String(kind), action))

func _on_fall(ctx) -> void:
	ctx._reset_after_fall_legacy(String(kind))

func _teardown(_ctx) -> void:
	pass
