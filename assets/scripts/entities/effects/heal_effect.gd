extends Effect
class_name HealEffect

@export var heal_amount : int = 20

func _init(_heal_amount: int = 20):
	heal_amount = _heal_amount
	effect_name = "Heal"

func apply_effect(target : CharacterBody2D) -> bool:
	if target.get("health_stats_script") != null:
		target.health_stats_script.heal(heal_amount)
		print("Wyleczono o: ", heal_amount)
		return true
	return false
