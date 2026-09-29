extends TimedEffect
class_name CooldownModifierEffect

@export_category("Modyfikatory Cooldownu")
## Wartość dodawana (np. +1.0 wydłuża cooldown o 1s, -0.5 skraca o 0.5s)
@export var cooldown_adder: float = 0.0
## Mnożnik (np. 0.5 to ataki 2x szybsze, 2.0 to ataki 2x wolniejsze)
@export var cooldown_multiplier: float = 1.0

func _init(_duration: float = 30.0, _adder: float = 0.0, _mult: float = 1.0):
	effect_name = "Cooldown Modifier"
	effect_color = Color.LIGHT_SKY_BLUE
	duration = _duration
	tick_interval = 0.0
	cooldown_adder = _adder
	cooldown_multiplier = _mult

func on_effect_start(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.cooldown_adder += cooldown_adder
		stats.cooldown_multiplier *= cooldown_multiplier
		print("Efekt Cooldownu nałożony! (", duration, "s)")

func on_effect_end(target: Node2D) -> void:
	if target.get("interaction_and_attack_stats_script") != null:
		var stats = target.interaction_and_attack_stats_script
		stats.cooldown_adder -= cooldown_adder
		if cooldown_multiplier != 0:
			stats.cooldown_multiplier /= cooldown_multiplier
