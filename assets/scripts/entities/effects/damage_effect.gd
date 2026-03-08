extends Effect
class_name DamageEffect

@export var damage_amount : int

func _init(_damage_amount: int):
	damage_amount = _damage_amount
	effect_name = "Damage"

func apply_effect(target : CharacterBody2D) -> bool:
	if target.get("health_stats_script") != null:
		target.health_stats_script.take_damage(damage_amount)
		print("Zadano obrażenia: ", damage_amount)
		return true
	return false
