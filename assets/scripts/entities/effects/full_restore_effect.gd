extends Effect
class_name FullRestoreEffect

func _init():
	effect_name = "Full Restore"

func apply_effect(target: Node2D) -> bool:
	if target.get("health_stats_script") != null:
		target.health_stats_script.heal_completely()
		print("Zdrowie zostało w pełni odnowione!")
		return true
	return false
