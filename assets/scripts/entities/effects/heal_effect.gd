extends Effect
class_name HealEffect

@export var heal_amount : int = 20
@export var allow_overheal : bool = false # Nowa flaga decydująca o bezwarunkowym zużyciu

func _init(_heal_amount: int = 20, _allow_overheal: bool = false):
	heal_amount = _heal_amount
	allow_overheal = _allow_overheal
	effect_name = "Heal"

func apply_effect(target : CharacterBody2D) -> bool:
	if target.get("health_stats_script") != null:
		var stats = target.health_stats_script
		
		# Sprawdzamy, czy gracz faktycznie potrzebuje leczenia 
		# LUB czy efekt wymusza zużycie (allow_overheal == true)
		if stats.health < stats.max_health or allow_overheal:
			stats.heal(heal_amount)
			print("Wyleczono o: ", heal_amount)
			return true
		else:
			print("Cel ma pełne zdrowie! Efekt odrzucony (przedmiot nie zostanie zużyty).")
			return false
			
	return false
