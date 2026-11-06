extends TimedEffect
class_name DamageModifierEffect

@export_category("Modyfikatory Obrażeń")
@export var damage_adder: float = 0.0
@export var damage_multiplier: float = 1.0

func _init(_duration: float = 10.0, _adder: float = 0.0, _mult: float = 1.0):
	effect_name = "Damage Modifier"
	effect_color = Color.CRIMSON
	duration = _duration
	tick_interval = 0.0
	damage_adder = _adder
	damage_multiplier = _mult
	effect_category = EffectCategory.STAT_DEBUFF if (_adder < 0.0 or _mult < 1.0) else EffectCategory.STAT_BUFF

func on_effect_start(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.damage_adder = snappedf(stats.damage_adder + damage_adder, 0.0001)
		stats.damage_multiplier = snappedf(stats.damage_multiplier * damage_multiplier, 0.0001)

func on_effect_end(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.damage_adder = snappedf(stats.damage_adder - damage_adder, 0.0001)
		if damage_multiplier != 0.0:
			stats.damage_multiplier = snappedf(stats.damage_multiplier / damage_multiplier, 0.0001)
