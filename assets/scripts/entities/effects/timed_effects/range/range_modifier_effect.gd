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
	effect_category = EffectCategory.STAT_DEBUFF if (_adder < 0.0 or _mult < 1.0) else EffectCategory.STAT_BUFF

func on_effect_start(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.range_adder = snappedf(stats.range_adder + range_adder, 0.0001)
		stats.range_multiplier = snappedf(stats.range_multiplier * range_multiplier, 0.0001)

func on_effect_end(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.range_adder = snappedf(stats.range_adder - range_adder, 0.0001)
		if range_multiplier != 0.0:
			stats.range_multiplier = snappedf(stats.range_multiplier / range_multiplier, 0.0001)
