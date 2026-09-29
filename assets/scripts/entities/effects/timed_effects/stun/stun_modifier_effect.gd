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

func on_effect_start(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.stun_adder += stun_adder
		stats.stun_multiplier *= stun_multiplier

func on_effect_end(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.stun_adder -= stun_adder
		if stun_multiplier != 0:
			stats.stun_multiplier /= stun_multiplier
