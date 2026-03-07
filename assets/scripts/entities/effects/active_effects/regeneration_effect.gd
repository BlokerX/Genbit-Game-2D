extends TimedEffect
class_name RegenerationEffect

@export var heal_per_tick : int = 5

func _init():
	effect_name = "Regeneration"
	duration = 10.0
	tick_interval = 2.0 # Leczy co 2 sekundy

func on_effect_tick(target: CharacterBody2D) -> void:
	if target.get("health_stats_script") != null:
		target.health_stats_script.heal(heal_per_tick)
		print("Regeneracja przywróciła ", heal_per_tick, " HP!")
