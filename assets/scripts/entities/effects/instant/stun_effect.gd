extends Effect
class_name StunEffect

@export var stun_time : float = 0.25

func _init(_stun_time: float = 0.25):
	stun_time = _stun_time
	effect_name = "Stun"

func apply_effect(target : Node2D) -> bool:
	if target.get("interaction_and_attack_stats_script") != null:
		var final_stun = stun_time
		
		# ODCZYT ODPORNOŚCI (TENACITY)
		if target.get("health_stats_script") != null:
			var cc_res = target.health_stats_script.cc_resistance
			if cc_res >= 1.0:
				print("Cel jest niewrażliwy na ogłuszenie!")
				return false
			final_stun *= (1.0 - cc_res) # Redukujemy czas stuna
		
		target.interaction_and_attack_stats_script.apply_stun_to_self(final_stun)
		print("Nałożono stun na: ", final_stun, "s")
		return true
	return false
