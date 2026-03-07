extends TimedEffect
class_name FrenzyBuffEffect

@export var bonus_damage : int = 15
@export var cooldown_reduction : float = 0.5

func _init():
	effect_name = "Frenzy Buff"
	duration = 8.0
	tick_interval = 0.0 # Brak tików, to tylko buff statystyk

func on_effect_start(target: CharacterBody2D) -> void:
	if target.get("attack_stats_script") != null:
		target.attack_stats_script.attack_damage += bonus_damage
		target.attack_stats_script.attack_cooldown -= cooldown_reduction
		print("Szał bojowy aktywowany! Więcej obrażeń, szybsze ataki!")

func on_effect_end(target: CharacterBody2D) -> void:
	if target.get("attack_stats_script") != null:
		# Przywracamy statystyki do normy
		target.attack_stats_script.attack_damage -= bonus_damage
		target.attack_stats_script.attack_cooldown += cooldown_reduction
		print("Szał bojowy minął.")
