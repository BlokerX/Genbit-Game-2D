extends TimedEffect
class_name PoisonEffect

@export var poison_damage_per_tick : int = 2

func _init():
	effect_name = "Poison"
	duration = 5.0
	tick_interval = 1.0 # Zadaje obrażenia co 1 sekundę

func on_effect_tick(target: CharacterBody2D) -> void:
	if target.get("health_stats_script") != null:
		target.health_stats_script.take_damage(poison_damage_per_tick)
		print("Trucizna zadaje ", poison_damage_per_tick, " obrażeń!")
