extends TimedEffect
class_name CritRateModifierEffect

@export_category("Modyfikatory Szansy na Kryta")
## Pamiętaj, że rate to procenty, więc +0.5 oznacza +50% szansy
@export var crit_rate_adder: float = 0.0
@export var crit_rate_multiplier: float = 1.0

func _init(_duration: float = 10.0, _adder: float = 0.0, _mult: float = 1.0):
	effect_name = "Critical Rate Modifier"
	effect_color = Color.GOLD
	duration = _duration
	tick_interval = 0.0
	crit_rate_adder = _adder
	crit_rate_multiplier = _mult

func on_effect_start(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.critical_rate_adder += crit_rate_adder
		stats.critical_rate_multiplier *= crit_rate_multiplier

func on_effect_end(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.critical_rate_adder -= crit_rate_adder
		if crit_rate_multiplier != 0:
			stats.critical_rate_multiplier /= crit_rate_multiplier
