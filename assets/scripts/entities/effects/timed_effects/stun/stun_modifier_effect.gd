extends TimedEffect
class_name StunModifierEffect

@export_category("Modyfikatory Ogłuszenia")
@export var stun_adder: float = 0.0
@export var stun_multiplier: float = 1.0

func _init(_duration: float = 10.0, _adder: float = 0.0, _mult: float = 1.0):
	effect_name = "Stun Modifier"
	effect_color = Color.PLUM
	duration = _duration
	tick_interval = 0.0
	stun_adder = _adder
	stun_multiplier = _mult
	effect_category = EffectCategory.STAT_DEBUFF if (_adder < 0.0 or _mult < 1.0) else EffectCategory.STAT_BUFF

func on_effect_start(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.stun_adder = snappedf(stats.stun_adder + stun_adder, 0.0001)
		stats.stun_multiplier = snappedf(stats.stun_multiplier * stun_multiplier, 0.0001)

func on_effect_end(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.stun_adder = snappedf(stats.stun_adder - stun_adder, 0.0001)
		if stun_multiplier != 0.0:
			stats.stun_multiplier = snappedf(stats.stun_multiplier / stun_multiplier, 0.0001)
