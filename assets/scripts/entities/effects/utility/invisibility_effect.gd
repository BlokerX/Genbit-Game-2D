extends TimedEffect
class_name InvisibilityEffect

const DEFAULT_INVISIBLE_ALPHA: float = 0.15

## Poziom przezroczystości postaci podczas działania niewidzialności (0.15 = ledwie widoczny kontur).
@export_range(0.0, 1.0, 0.05) var invisible_alpha: float = DEFAULT_INVISIBLE_ALPHA

func _init(_duration: float = 12.0):
	effect_name = "Invisibility"
	effect_color = Color.TRANSPARENT
	effect_category = EffectCategory.UTILITY
	duration = _duration
	tick_interval = 0.0

func on_effect_start(target: Node2D) -> void:
	target.set_meta("is_invisible", true)
	target.set_meta("invisible_alpha_value", invisible_alpha)
	# NAPRAWA KRYTYCZNA: Nigdy nie usuwamy gracza z grupy "Player"!
	# PerceptionComponent sprawdza target.has_meta("is_invisible"), a grupa "Player"
	# jest niezbędna dla WorldStreamera, Minimapy, Drzwi oraz UI.
	if target.has_method("refresh_visual_appearance"):
		target.call("refresh_visual_appearance")
	_drop_ai_aggro_from_target(target)

func on_effect_end(target: Node2D) -> void:
	if target.has_meta("is_invisible"):
		target.remove_meta("is_invisible")
	if target.has_meta("invisible_alpha_value"):
		target.remove_meta("invisible_alpha_value")
	if target.has_method("refresh_visual_appearance"):
		target.call("refresh_visual_appearance")

## Sprawia, że przeciwnicy aktualnie goniący cel gubią go w momencie zniknięcia.
func _drop_ai_aggro_from_target(target: Node2D) -> void:
	if not target.is_inside_tree():
		return
	for char_node in target.get_tree().get_nodes_in_group("Character"):
		if char_node == target:
			continue
		var ai_ctrl = char_node.get_node_or_null("AIController")
		if ai_ctrl and ai_ctrl.get("blackboard") != null and ai_ctrl.blackboard.target == target:
			ai_ctrl.blackboard.target = null
