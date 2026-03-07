extends TimedEffect
class_name MaxHealthBuffEffect

@export var health_boost : int = 50

func _init():
	effect_name = "Max Health Buff"
	duration = 30.0
	tick_interval = 0.0 # Nie potrzebujemy tików

func on_effect_start(target: CharacterBody2D) -> void:
	if target.get("health_stats_script") != null:
		target.health_stats_script.boost_max_health(health_boost)
		print("Zwiększono max HP o ", health_boost)

func on_effect_end(target: CharacterBody2D) -> void:
	if target.get("health_stats_script") != null:
		target.health_stats_script.reduce_max_health(health_boost)
		print("Buff do max HP wygasł!")
