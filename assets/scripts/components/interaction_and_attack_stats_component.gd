extends Resource
class_name InteractionAndAttackStatsComponent
## Komponent statystyk bojowych i interakcji zarządzający obrażeniami, szansą krytyczną,
## zasięgiem oraz globalnym zegarem czasu odnowienia (Cooldown / Reload / Stun).

# --- STAŁE DOMENOWE (Brak magicznych liczb) ---
const DEFAULT_HAND_DAMAGE: int = 10
const DEFAULT_HAND_CRIT_DAMAGE: int = 0
const DEFAULT_HAND_CRIT_RATE: float = 0.0
const DEFAULT_HAND_RANGE: float = 100.0
const DEFAULT_HAND_STUN_TIME: float = 0.25

const MIN_ALLOWED_COOLDOWN_SECONDS: float = 0.05
const MAX_IDLE_COOLDOWN_ACCUMULATION: float = 60.0
const MAX_ARMOR_PENETRATION: float = 1.0
const DEFAULT_MAX_TOTAL_COOLDOWN_LOCK_SEC: float = 8.0

#region Cooldown timer
signal cooldown_started
signal cooldown_ready

## Zmienna przechowująca upływający czas, jeśli jest równy lub większy niż max to można wykonać atak.
var cooldown_timer: float = 1.0
## Zmienna przechowująca aktualny limit cooldowna (zależne od itemu/ręki...).
var actual_cooldown: float = 1.0
## Całkowity czas trwania bieżącego cyklu odnowienia/przeładowania/ogłuszenia (do płynnego skalowania paska CooldownUI).
var _current_cycle_duration: float = 1.0
#endregion

#region Konfiguracja zabezpieczeń Cooldownu i Respawnu
@export_group("Zabezpieczenia Cooldownu i Respawnu")
## Czy kolejne efekty ogłuszenia (Stun) otrzymane w tym samym czasie mają się sumować (true),
## czy też obowiązuje zasada najdłuższego aktywnego ogłuszenia bez kumulacji w nieskończoność (false - domyślnie)?
@export var stack_stun_durations: bool = false
## Maksymalny łączny czas blokady akcji (w sekundach), jaki może zostać nałożony na postać (chroni przed wielominutowym cooldownem).
@export_range(1.0, 30.0, 0.5) var max_total_cooldown_lock_seconds: float = DEFAULT_MAX_TOTAL_COOLDOWN_LOCK_SEC
## Czy po śmierci i respawnie postaci zegar cooldownu ma być automatycznie resetowany do stanu gotowości?
@export var reset_cooldown_on_respawn: bool = true
#endregion

#region Stats multipliers
# Damage buff
@export var damage_adder: float = 0.0
@export var damage_multiplier: float = 1.0

# Crit damage
@export var critical_damage_adder: float = 0.0
@export var critical_damage_multiplier: float = 1.0

# Crit rate
@export var critical_rate_adder: float = 0.0
@export var critical_rate_multiplier: float = 1.0

# Range buff
@export var range_adder: float = 0.0
@export var range_multiplier: float = 1.0

# Stun buff
@export var stun_adder: float = 0.0
@export var stun_multiplier: float = 1.0

# Knockback buff
@export var knockback_adder: float = 0.0
@export var knockback_multiplier: float = 1.0

@export var armor_penetration_adder: float = 0.0

# Cooldown buff
@export var cooldown_adder: float = 0.0
@export var cooldown_multiplier: float = 1.0
#endregion

#region Stats
## Ręka - domyślne ustawienia.
@export var hand_attack_data: AttackData = null
@export var hand_attack_cooldown: float = 1.0
## Aktualne dane ataku.
var actual_attack_data: AttackData = null
## Dodatkowe efekty (jeśli są).
var actual_extra_effects: Array[Effect] = []
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

	var initial_cd: float = get_total_actual_cooldown()
	cooldown_timer = initial_cd
	_current_cycle_duration = initial_cd

func get_total_damage() -> int:
	if actual_attack_data == null:
		return int(damage_adder * damage_multiplier)
	return int((actual_attack_data.damage + damage_adder) * damage_multiplier)

func get_total_critical_damage() -> int:
	if actual_attack_data == null:
		return int(critical_damage_adder * critical_damage_multiplier)
	return int((actual_attack_data.critical_damage + critical_damage_adder) * critical_damage_multiplier)

func get_total_critical_rate() -> float:
	if actual_attack_data == null:
		return critical_rate_adder * critical_rate_multiplier
	return (actual_attack_data.critical_rate + critical_rate_adder) * critical_rate_multiplier

func get_total_range() -> float:
	if actual_attack_data == null:
		return maxf(0.0, range_adder * range_multiplier)
	return maxf(0.0, (actual_attack_data.max_range + range_adder) * range_multiplier)

func get_total_stun() -> float:
	if actual_attack_data == null:
		return maxf(0.0, stun_adder * stun_multiplier)
	return maxf(0.0, (actual_attack_data.stun_time + stun_adder) * stun_multiplier)

## Obliczanie ostatecznej wartości odrzutu.
func get_total_knockback() -> float:
	if actual_attack_data == null:
		return maxf(0.0, knockback_adder * knockback_multiplier)
	return maxf(0.0, (actual_attack_data.knockback_force + knockback_adder) * knockback_multiplier)

## Funkcja licząca całkowitą penetrację pancerza (ucinamy na MAX_ARMOR_PENETRATION = 1.0).
func get_total_armor_penetration() -> float:
	if actual_attack_data != null:
		return clampf(actual_attack_data.armor_penetration + armor_penetration_adder, 0.0, MAX_ARMOR_PENETRATION)
	return clampf(armor_penetration_adder, 0.0, MAX_ARMOR_PENETRATION)

func get_total_actual_cooldown() -> float:
	# Tu również aktualny cooldown zależy od tego czym atakujemy (z bezpiecznym dolnym i górnym progiem)
	var raw_cd: float = (actual_cooldown + cooldown_adder) * cooldown_multiplier
	return clampf(raw_cd, MIN_ALLOWED_COOLDOWN_SECONDS, maxf(MIN_ALLOWED_COOLDOWN_SECONDS, max_total_cooldown_lock_seconds))

## Zwraca pozostały czas odnowienia w sekundach (0.0 oznacza pełną gotowość do ataku).
func get_remaining_cooldown() -> float:
	return maxf(0.0, get_total_actual_cooldown() - cooldown_timer)

## Zwraca znormalizowany postęp odnowienia w przedziale 0.0 (start) .. 1.0 (gotowe) dla paska CooldownUI.
func get_cooldown_progress_ratio() -> float:
	var remaining: float = get_remaining_cooldown()
	if remaining <= 0.0:
		return 1.0
	var cycle_total: float = maxf(MIN_ALLOWED_COOLDOWN_SECONDS, maxf(_current_cycle_duration, remaining))
	return clampf(1.0 - (remaining / cycle_total), 0.0, 1.0)

func can_attack() -> bool:
	return cooldown_timer >= get_total_actual_cooldown()

## Nakłada blokadę ogłuszenia (Stun) na zegar akcji bez nieskończonej kumulacji czasu oczekiwania.
func apply_stun_to_self(seconds: float) -> void:
	if seconds <= 0.0:
		return

	var max_cd: float = get_total_actual_cooldown()
	var clamped_stun: float = minf(seconds, max_total_cooldown_lock_seconds)
	var current_remaining: float = get_remaining_cooldown()

	var new_remaining: float = clamped_stun
	if stack_stun_durations:
		# Jeśli włączono sumowanie stunów, nadal ograniczamy sumę do max_total_cooldown_lock_seconds
		new_remaining = minf(current_remaining + clamped_stun, max_total_cooldown_lock_seconds)
	else:
		# Domyślnie: obowiązuje dłuższy z czasów (brak kumulacji do 5 minut przy serii ciosów!)
		new_remaining = maxf(current_remaining, clamped_stun)

	cooldown_timer = max_cd - new_remaining
	_current_cycle_duration = maxf(max_cd, new_remaining)

	# Budzimy pasek CooldownUI, gdy wróg nałoży na nas Stun!
	if cooldown_timer < max_cd:
		cooldown_started.emit()

## Ujednolicona funkcja ataku. Nakłada wygenerowane Efekty na cel.
func execute_attack_on_target(actor: Node2D, target: Node2D) -> void:
	# 1. Generujemy gotową listę bazowych efektów z actual_attack_data (Damage, Stun, Knockback)
	var all_effects: Array[Effect] = generate_attack_effects()

	# Klonujemy i dorzucamy efekty specjalne (np. z broni)
	for eff in actual_extra_effects:
		if eff != null:
			all_effects.append(eff.duplicate(true))

	# UNIWERSALNE WSTRZYKIWANIE (Duck Typing)
	for effect in all_effects:
		if is_instance_valid(actor):
			effect.source_position = actor.global_position
			effect.source_entity = actor

		if is_instance_valid(target):
			if target.has_method("receive_effect"):
				target.receive_effect(effect)
			else:
				effect.apply_effect(target)

	# Resetujemy cooldown
	reset_cooldown()

## Zwraca gotową listę efektów (Damage, Stun, Knockback), uwzględniając szansę na Crit.
func generate_attack_effects() -> Array[Effect]:
	var effects: Array[Effect] = []

	# 1. Obliczamy finalne obrażenia z mnożnikami gracza
	var final_damage: int = get_total_damage()
	var final_crit_rate: float = get_total_critical_rate()
	var final_crit_dmg: int = get_total_critical_damage()
	var final_stun: float = get_total_stun()
	var final_knockback: float = get_total_knockback()
	var final_penetration: float = get_total_armor_penetration()

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

## Generuje listę wszystkich efektów, dołącza te z broni i resetuje cooldown.
func get_all_attack_effects() -> Array[Effect]:
	var all_effects: Array[Effect] = generate_attack_effects()
	all_effects.append_array(actual_extra_effects)
	reset_cooldown()
	return all_effects

# --- FUNKCJA ZMIANY PRZEDMIOTU ---
## Zmienia bazowy cooldown przy przełączeniu przedmiotu, zachowując ewentualny pozostały czas blokady.
func change_item_cooldown(new_cooldown: float) -> void:
	var previous_remaining: float = get_remaining_cooldown()
	actual_cooldown = maxf(MIN_ALLOWED_COOLDOWN_SECONDS, new_cooldown)
	var new_max_cd: float = get_total_actual_cooldown()

	if previous_remaining > 0.0:
		var clamped_rem: float = minf(previous_remaining, max_total_cooldown_lock_seconds)
		cooldown_timer = new_max_cd - clamped_rem
		_current_cycle_duration = maxf(new_max_cd, clamped_rem)
		cooldown_started.emit()
	else:
		cooldown_timer = new_max_cd
		_current_cycle_duration = new_max_cd
		cooldown_ready.emit()

# --- ZAKTUALIZOWANA FUNKCJA ODLICZANIA (GLOBALNY ZEGAR) ---
func interaction_cooldown_process(delta: float) -> void:
	var max_cooldown: float = get_total_actual_cooldown()
	var was_ready: bool = cooldown_timer >= max_cooldown

	# Zabezpieczenie przed przekroczeniem maksymalnego czasu blokady
	var min_allowed_timer: float = max_cooldown - max_total_cooldown_lock_seconds
	if cooldown_timer < min_allowed_timer:
		cooldown_timer = min_allowed_timer

	# Czas płynie zawsze, niezależnie od tego, co trzymasz w dłoni!
	if cooldown_timer < MAX_IDLE_COOLDOWN_ACCUMULATION:
		cooldown_timer += delta

	var is_ready: bool = cooldown_timer >= max_cooldown

	# Wysyłamy sygnał gotowości do UI TYLKO W MOMENCIE przejścia paska
	if not was_ready and is_ready:
		_current_cycle_duration = max_cooldown
		cooldown_ready.emit()

## Ustawia cooldown timer aby odliczał od początku.
func reset_cooldown() -> void:
	cooldown_timer = 0.0
	_current_cycle_duration = get_total_actual_cooldown()
	cooldown_started.emit()

## Wymusza długi czas oczekiwania (wykorzystywane do animacji przeładowania) bez kumulacji w nieskończoność.
func trigger_reload_cooldown(reload_seconds: float) -> void:
	var safe_reload: float = clampf(reload_seconds, MIN_ALLOWED_COOLDOWN_SECONDS, max_total_cooldown_lock_seconds)
	var max_cooldown: float = get_total_actual_cooldown()
	var current_remaining: float = get_remaining_cooldown()
	var final_wait: float = maxf(current_remaining, safe_reload)

	cooldown_timer = max_cooldown - final_wait
	_current_cycle_duration = maxf(max_cooldown, final_wait)
	# Wysyłamy sygnał do UI, by pasek zaczął się ładować od nowa
	cooldown_started.emit()

## Resetuje stan zegara cooldownu podczas śmierci i respawnu postaci.
func reset_for_respawn(clear_stat_modifiers: bool = false) -> void:
	if clear_stat_modifiers:
		damage_adder = 0.0
		damage_multiplier = 1.0
		critical_damage_adder = 0.0
		critical_damage_multiplier = 1.0
		critical_rate_adder = 0.0
		critical_rate_multiplier = 1.0
		range_adder = 0.0
		range_multiplier = 1.0
		stun_adder = 0.0
		stun_multiplier = 1.0
		knockback_adder = 0.0
		knockback_multiplier = 1.0
		armor_penetration_adder = 0.0
		cooldown_adder = 0.0
		cooldown_multiplier = 1.0

	if reset_cooldown_on_respawn:
		var max_cd: float = get_total_actual_cooldown()
		cooldown_timer = max_cd
		_current_cycle_duration = max_cd
		cooldown_ready.emit()
