extends TimedEffect
class_name RangeModifierEffect

@export_category("Modyfikatory Zasięgu")
@export var range_adder: float = 0.0
@export var range_multiplier: float = 1.0

func _init(_duration: float = 10.0, _adder: float = 0.0, _mult: float = 1.0):
	effect_name = "Range Modifier"
	effect_color = Color.GREEN_YELLOW
	duration = _duration
	tick_interval = 0.0
	range_adder = _adder
	range_multiplier = _mult

func on_effect_start(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.range_adder += range_adder
		stats.range_multiplier *= range_multiplier

func on_effect_end(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.range_adder -= range_adder
		if range_multiplier != 0:
			stats.range_multiplier /= range_multiplier
