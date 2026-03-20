extends Effect
class_name StunEffect

@export var stun_time : float = 0.25

func _init(_stun_time: float = 0.25):
	stun_time = _stun_time
	effect_name = "Stun"

func apply_effect(target : CharacterBody2D) -> bool:
	if target.get("interaction_and_attack_stats_script") != null:
		target.interaction_and_attack_stats_script.apply_stun(stun_time)
		print("Nałożono stun na: ", stun_time, "s")
		return true
	return false
