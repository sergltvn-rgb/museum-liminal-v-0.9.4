class_name RiftTrial
extends Node
## Scene-backed definition shared by every pocket-dimension trial.
## Runtime mechanics stay behind RiftTrialManager's stable public contract.

@export var kind: StringName
@export var title_key: StringName
@export_multiline var objective_ru := ""
@export_multiline var objective_en := ""
@export_multiline var tutorial_ru := ""
@export_multiline var tutorial_en := ""
@export_multiline var fail_tip_ru := ""
@export_multiline var fail_tip_en := ""

func localized_title() -> String:
	var translated := tr(String(title_key))
	return translated if translated != String(title_key) else String(title_key)

func objective() -> String:
	return objective_en if TranslationServer.get_locale().begins_with("en") else objective_ru

func tutorial_steps() -> PackedStringArray:
	var source := tutorial_en if TranslationServer.get_locale().begins_with("en") else tutorial_ru
	return source.split("\n", false)

func fail_tip() -> String:
	return fail_tip_en if TranslationServer.get_locale().begins_with("en") else fail_tip_ru

func build(manager: Node) -> void:
	manager.call("_build_trial_legacy", String(kind))

func process_trial(manager: Node, delta: float) -> void:
	manager.call("_process_trial_legacy", String(kind), delta)

func interact(manager: Node) -> void:
	manager.call("_interact_trial_legacy")

func secondary_action(manager: Node, action: StringName) -> bool:
	return bool(manager.call("_secondary_action_legacy", String(kind), action))

func reset_after_fall(manager: Node) -> void:
	manager.call("_reset_after_fall_legacy", String(kind))

func cleanup(_manager: Node) -> void:
	pass
