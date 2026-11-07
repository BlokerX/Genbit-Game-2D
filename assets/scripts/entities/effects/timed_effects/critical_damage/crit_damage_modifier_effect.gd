extends TimedEffect
class_name CritDamageModifierEffect

@export_category("Modyfikatory Mocy Krytyka")
@export var crit_damage_adder: float = 0.0
@export var crit_damage_multiplier: float = 1.0

func _init(_duration: float = 10.0, _adder: float = 0.0, _mult: float = 1.0):
	effect_name = "Critical Damage Modifier"
	effect_color = Color.DARK_ORANGE
	duration = _duration
	tick_interval = 0.0
	crit_damage_adder = _adder
	crit_damage_multiplier = _mult
	effect_category = EffectCategory.STAT_DEBUFF if (_adder < 0.0 or _mult < 1.0) else EffectCategory.STAT_BUFF

func on_effect_start(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.critical_damage_adder = snap_stat_addition(stats.critical_damage_adder, crit_damage_adder)
		stats.critical_damage_multiplier = snap_stat_multiplication(stats.critical_damage_multiplier, crit_damage_multiplier)

func on_effect_end(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.critical_damage_adder = snap_stat_addition(stats.critical_damage_adder, -crit_damage_adder)
		stats.critical_damage_multiplier = snap_stat_division(stats.critical_damage_multiplier, crit_damage_multiplier)
