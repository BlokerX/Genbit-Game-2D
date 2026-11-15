extends Effect
class_name StunEffect

const MIN_STUN_TIME_SEC: float = 0.02
const FULL_CC_RESISTANCE: float = 1.0

@export var stun_time : float = 0.25

func _init(_stun_time: float = 0.25) -> void:
	stun_time = _stun_time
	effect_name = "Stun"
	effect_category = EffectCategory.STUN

func apply_duration_multiplier(multiplier: float) -> void:
	stun_time = maxf(0.0, stun_time * maxf(0.0, multiplier))

func apply_potency_multiplier(multiplier: float) -> void:
	stun_time = maxf(0.0, stun_time * maxf(0.0, multiplier))

func apply_effect(target : Node2D) -> bool:
	if target.get("interaction_and_attack_stats_script") != null:
		var final_stun: float = stun_time

		if target.get("health_stats_script") != null:
			var cc_res: float = float(target.health_stats_script.cc_resistance)
			if cc_res >= FULL_CC_RESISTANCE:
				print("Cel jest niewrażliwy na ogłuszenie!")
				return false
			final_stun *= (1.0 - clampf(cc_res, 0.0, FULL_CC_RESISTANCE))

		if final_stun < MIN_STUN_TIME_SEC:
			return false

		target.interaction_and_attack_stats_script.apply_stun_to_self(final_stun)
		print("Nałożono stun na: ", final_stun, "s")
		return true
	return false

func is_offensive() -> bool:
	return true
