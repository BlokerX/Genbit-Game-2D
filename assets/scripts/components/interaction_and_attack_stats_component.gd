extends Resource
class_name InteractionAndAttackStatsComponent

# --- STAŁE DOMENOWE (Brak magicznych liczb) ---
const DEFAULT_HAND_DAMAGE: int = 10
const DEFAULT_HAND_CRIT_DAMAGE: int = 0
const DEFAULT_HAND_CRIT_RATE: float = 0.0
const DEFAULT_HAND_RANGE: float = 100.0
const DEFAULT_HAND_STUN_TIME: float = 0.25

const MIN_ALLOWED_COOLDOWN_SECONDS: float = 0.05
const MAX_IDLE_COOLDOWN_ACCUMULATION: float = 60.0
const MAX_ARMOR_PENETRATION: float = 1.0

#region Cooldown timer
signal cooldown_started
signal cooldown_ready

# Zmienna przechowująca czas, jeśli jest równy max to można wykonać atak.
var cooldown_timer : float = 1.0
# Zmienna przechowująca aktualny limit cooldowna (zależne od itemu/ręki...) 
var actual_cooldown : float = 1.0
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

# Knockback buff
@export var knockback_adder : float = 0.0
@export var knockback_multiplier : float = 1.0

@export var armor_penetration_adder : float = 0.0

# Cooldown buff
@export var cooldown_adder : float = 0.0
@export var cooldown_multiplier : float = 1.0
#endregion

#region Stats
## Ręka - domyślne ustawienia.
@export var hand_attack_data : AttackData = null
@export var hand_attack_cooldown : float = 1.0
## Aktualne dane ataku.
var actual_attack_data : AttackData = null
## Dodatkowe efekty (jeśli są).
var actual_extra_effects : Array[Effect] = []
#endregion

func _init() -> void:
	# Jeśli Inspektor załadował pustą wartość, wymuszamy nasze domyślne dane:
	if hand_attack_data == null:
		hand_attack_data = AttackData.new(
			DEFAULT_HAND_DAMAGE,
			DEFAULT_HAND_CRIT_DAMAGE,
			DEFAULT_HAND_CRIT_RATE,
			DEFAULT_HAND_RANGE,
			DEFAULT_HAND_STUN_TIME
		)

	# Zabezpieczamy również zmienną actual_attack_data na starcie
	if actual_attack_data == null:
		actual_attack_data = hand_attack_data

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

# Obliczanie ostatecznej wartości odrzutu
func get_total_knockback() -> float:
	return ( actual_attack_data.knockback_force + knockback_adder ) * knockback_multiplier

# Funkcja licząca całkowitą penetrację pancerza (ucinamy na MAX_ARMOR_PENETRATION = 1.0)
func get_total_armor_penetration() -> float:
	if actual_attack_data != null:
		return clamp(actual_attack_data.armor_penetration + armor_penetration_adder, 0.0, MAX_ARMOR_PENETRATION)
	return clamp(armor_penetration_adder, 0.0, MAX_ARMOR_PENETRATION)

func get_total_actual_cooldown() -> float:
	# Tu również aktualny cooldown zależy od tego czym atakujemy
	return max(MIN_ALLOWED_COOLDOWN_SECONDS, ( actual_cooldown + cooldown_adder ) * cooldown_multiplier)

func can_attack() -> bool:
	if cooldown_timer < get_total_actual_cooldown():
		return false
	return true

func apply_stun_to_self(seconds : float) -> void :
	if seconds <= 0.0:
		return
	var max_cd := get_total_actual_cooldown()
	# Jeśli broń była już gotowa (np. cooldown_timer == 60.0 po długim staniu),
	# cofamy licznik względem max_cd, aby ogłuszenie trwało dokładnie 'seconds' sekund!
	if cooldown_timer > max_cd:
		cooldown_timer = max_cd - seconds
	else:
		cooldown_timer -= seconds

	# NAPRAWA: Budzimy pasek CooldownUI, gdy wróg nałoży na nas Stun!
	if cooldown_timer < max_cd:
		cooldown_started.emit()

## Ujednolicona funkcja ataku. Nakłada wygenerowane Efekty na cel.
func execute_attack_on_target(actor: Node2D, target: Node2D) -> void :
	# 1. Generujemy gotową listę bazowych efektów z actual_attack_data (Damage i Stun)
	var all_effects : Array[Effect] = generate_attack_effects()

	# Klonujemy i dorzucamy efekty specjalne (np. z broni)
	for eff in actual_extra_effects:
		if eff != null:
			all_effects.append(eff.duplicate(true))

	# UNIWERSALNE WSTRZYKIWANIE (Duck Typing)
	for effect in all_effects:
		effect.source_position = actor.global_position
		# --- BEZPIECZNE PRZYPISANIE SPRAWCY ---
		if is_instance_valid(actor):
			effect.source_entity = actor

		if target.has_method("receive_effect"):
			target.receive_effect(effect)
		else:
			effect.apply_effect(target)

	# Resetujemy cooldown
	reset_cooldown()

# Zwraca gotową listę efektów (Damage, Stun), uwzględniając szansę na Crit
func generate_attack_effects() -> Array[Effect]:
	var effects : Array[Effect] = []

	# 1. Obliczamy finalne obrażenia z mnożnikami gracza
	var final_damage = get_total_damage()
	var final_crit_rate = get_total_critical_rate()
	var final_crit_dmg = get_total_critical_damage()
	var final_stun = get_total_stun()
	var final_knockback = get_total_knockback()
	var final_penetration = get_total_armor_penetration()

	# 2. Szansa na cios krytyczny
	if randf() <= final_crit_rate:
		final_damage += int(final_crit_dmg)
		print("KRYTYK! Obrażenia: ", final_damage)

	# 3. Tworzymy efekty
	effects.append(DamageEffect.new(final_damage, final_penetration))

	if final_stun > 0.0:
		effects.append(StunEffect.new(final_stun))

	if final_knockback > 0.0:
		effects.append(KnockbackEffect.new(final_knockback))

	return effects

## Generuje listę wszystkich efektów, dołącza te z broni i resetuje cooldown
func get_all_attack_effects() -> Array[Effect]:
	var all_effects : Array[Effect] = generate_attack_effects()
	all_effects.append_array(actual_extra_effects)
	reset_cooldown()
	return all_effects

# --- FUNKCJA ZMIANY PRZEDMIOTU ---
func change_item_cooldown(new_cooldown: float) -> void:
	actual_cooldown = new_cooldown
	# Natychmiastowe odświeżenie UI przy zmianie slotu
	if cooldown_timer >= get_total_actual_cooldown():
		cooldown_ready.emit()
	else:
		cooldown_started.emit()

# --- ZAKTUALIZOWANA FUNKCJA ODLICZANIA (GLOBALNY ZEGAR) ---
func interaction_cooldown_process(delta : float) -> void :
	var max_cooldown = get_total_actual_cooldown()
	var was_ready = cooldown_timer >= max_cooldown

	# Czas płynie zawsze, niezależnie od tego, co trzymasz w dłoni!
	if cooldown_timer < MAX_IDLE_COOLDOWN_ACCUMULATION:
		cooldown_timer += delta

	var is_ready = cooldown_timer >= max_cooldown

	# Wysyłamy sygnał gotowości do UI TYLKO W MOMENCIE przejścia paska
	if not was_ready and is_ready:
		cooldown_ready.emit()

## Ustawia cooldown timer aby odliczał od początku.
func reset_cooldown() -> void:
	cooldown_timer = 0.0
	cooldown_started.emit()

## Wymusza długi czas oczekiwania (wykorzystywane do animacji przeładowania)
func trigger_reload_cooldown(reload_seconds: float) -> void:
	var max_cooldown = get_total_actual_cooldown()
	cooldown_timer = max_cooldown - reload_seconds
	# Wysyłamy sygnał do UI, by pasek zaczął się ładować od nowa
	cooldown_started.emit()
