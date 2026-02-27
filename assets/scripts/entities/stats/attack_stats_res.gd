extends Resource

class_name AttackStatsComponent

# Zmienna przechowująca czas do następnego ataku
var attack_cooldown_timer : float = 0.0

@export var attack_damage : int = 10
@export var attack_cooldown : float = 1.0

func can_attack() -> bool :
	if attack_cooldown_timer > 0 :
		return false
	return true

func attack(target : CharacterBody2D) -> void :
	target.stats_script.take_damage(attack_damage)
	attack_cooldown_timer = attack_cooldown

func attack_cooldown_process(delta : float) -> void :
	# Odmierzanie czasu - zmniejszamy licznik o ułamek sekundy w każdej klatce
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
