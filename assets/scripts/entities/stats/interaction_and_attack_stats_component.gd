extends Resource

class_name InteractionAndAttackStatsComponent

#region Cooldown timer

# Zmienna przechowująca czas, jeśli jest równy max to można wykonać atak.
var cooldown_timer : float = 1.0
# Zmienna przechowująca aktualny limit cooldowna (zależne od itemu/ręki...) 
var actual_cooldown : float = 1.0
# nie tylko weapons 
# trzeba będzie zmienić nazwę tego komponentu ale nie wiem na jaką jeszcze

#endregion

#region Stats multipliers

# Damage buff
@export var damage_adder : float = 0.0
@export var damage_multiplier : float = 1.0

# Crit damage
@export var critical_damage_adder : float = 0.0
@export var critical_damage_multiplier : float = 1.0

# Crit rate
@export var critical_rate_adder : float = 0.0
@export var critical_rate_multiplier : float = 1.0

# Range buff
@export var range_adder : float = 0.0
@export var range_multiplier : float = 1.0

# Stun buff
@export var stun_adder : float = 0.0
@export var stun_multiplier : float = 1.0

# --- #

# Cooldown buff
@export var cooldown_adder : float = 0.0
@export var cooldown_multiplier : float = 1.0

#endregion

#region Stats

## Ręka - domyślne ustawienia.
@export var hand_attack_data : AttackData = AttackData.new(10, 0, 0.0, 100.0, 0.25)
@export var hand_attack_cooldown : float = 1.0

## Aktualne dane ataku.
var actual_attack_data : AttackData = hand_attack_data

## Dodatkowe efekty (jeśli jest).
var actual_extra_effects : Array[Effect] = []

#endregion

func get_total_damage() -> int:
	return int( ( actual_attack_data.damage + damage_adder ) * damage_multiplier )

func get_total_critical_damage() -> int:
	return int( ( actual_attack_data.critical_damage + critical_damage_adder ) * critical_damage_multiplier )

func get_total_critical_rate() -> float:
	return ( actual_attack_data.critical_rate + critical_rate_adder ) * critical_rate_multiplier

func get_total_range() -> float:
	return ( actual_attack_data.max_range + range_adder ) * range_multiplier

func get_total_stun() -> float:
	return ( actual_attack_data.stun_time + stun_adder ) * stun_multiplier

func get_total_actual_cooldown() -> float:
	# Tu również aktualny cooldown zależy od tego czym atakujemy
	return ( actual_cooldown + cooldown_adder ) * cooldown_multiplier

func can_attack() -> bool:
	if cooldown_timer < get_total_actual_cooldown():
		return false
	return true

func apply_stun_to_self(seconds : float) -> void :
	cooldown_timer -= seconds

## Ujednolicona funkcja ataku. Nakłada wygenerowane Efekty na cel.
func execute_attack_on_target(target : Node2D) -> void :
	# 1. Generujemy gotową listę bazowych efektów z actual_attack_data (Damage i Stun)
	var all_effects : Array[Effect] = generate_attack_effects()
	
	# 2. Dorzucamy do listy dodatkowe efekty (np. PoisonEffect, FireEffect z broni)
	all_effects.append_array(actual_extra_effects)
	
	# 3. Nakładamy WSZYSTKIE efekty na wroga w jednej spójnej pętli
	for effect in all_effects:
		if target.has_method("receive_effect"):
			target.receive_effect(effect)
		else:
			# Fallback dla obiektów, które nie obsługują receive_effect
			effect.apply_effect(target)
			
	# Resetujemy cooldown
	reset_cooldown()

# Zwraca gotową listę efektów (Damage, Stun), uwzględniając szansę na Crit
# Jako argument przyjmuje "mnożniki" z Twojego komponentu statystyk gracza
func generate_attack_effects() -> Array[Effect]:
	var effects : Array[Effect] = []
	
	# 1. Obliczamy finalne obrażenia z mnożnikami gracza
	var final_damage = get_total_damage()
	var final_crit_rate = get_total_critical_rate()
	var final_crit_dmg = get_total_critical_damage()
	var final_stun = get_total_stun()
	
	# 2. Szansa na cios krytyczny
	if randf() <= final_crit_rate:
		final_damage += int(final_crit_dmg)
		print("KRYTYK! Obrażenia: ", final_damage)
	
	# 3. Tworzymy efekty
	effects.append(DamageEffect.new(final_damage))
	
	if final_stun > 0.0:
		effects.append(StunEffect.new(final_stun))
		
	return effects

## Generuje listę wszystkich efektów, dołącza te z broni i resetuje cooldown
func get_all_attack_effects() -> Array[Effect]:
	var all_effects : Array[Effect] = generate_attack_effects()
	all_effects.append_array(actual_extra_effects)
	reset_cooldown()
	return all_effects

func interaction_cooldown_process(delta : float) -> void :
	if cooldown_timer < get_total_actual_cooldown():
		cooldown_timer += delta

## Ustawia cooldown timer aby odliczał od początku.
func reset_cooldown() -> void:
	cooldown_timer = 0.0
