extends Effect
class_name InstaKillEffect

func _init():
	effect_name = "Insta-Kill"

func apply_effect(target: Node2D) -> bool:
	if target.get("health_stats_script") != null:
		target.health_stats_script.kill()
		print("CEL ZOSTAŁ NATYCHMIAST ZNISZCZONY!")
		return true
	return false
