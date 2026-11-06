extends Resource
class_name LifeStatsComponent

signal health_changed(new_health, max_health)
## Emitowany TYLKO wtedy, gdy zdrowie faktycznie wzrosło (amount_restored > 0).
## Parametr is_silent pozwala wyciszyć zielony błysk ekranu (np. dla pasywnych spodni czy Nieśmiertelności).
signal health_healed(amount_restored: int, is_silent: bool)
signal died

# --- STAŁE DOMENOWE (Brak magicznych liczb) ---
const DEFAULT_MAX_HEALTH: int = 100
const MIN_DAMAGE_AFTER_ARMOR: int = 1
const IMMORTALITY_SURVIVAL_HP: int = 1
const FULL_RESISTANCE_THRESHOLD: float = 1.0

@export_group("Zdrowie")
@export var health : int = DEFAULT_MAX_HEALTH
@export var max_health : int = DEFAULT_MAX_HEALTH:
	set(value):
		max_health = maxi(1, value)
		if _initial_max_health <= 0:
			_initial_max_health = max_health

@export_group("Pancerz i Obrona")
@export var base_armor: float = 0.0

var armor_adder: float = 0.0
var armor_multiplier: float = 1.0
var _initial_max_health: int = 0

@export_group("Odporności i Ciernie")
## Odporność na kontrolę tłumu (0.0 = 0%, 1.0 = 100% niewrażliwości na odrzut i ogłuszenie)
@export_range(0.0, 1.0) var cc_resistance: float = 0.0

## Kategorie efektów, na które ta postać jest całkowicie odporna (np. POISON_ACID dla kwasowego bossa).
@export var immune_categories: Array[Effect.EffectCategory] = []

## Konkretne nazwy efektów (effect_name), na które postać jest całkowicie odporna.
@export var immune_effect_names: Array[StringName] = []

## Płaskie obrażenia zwrotne (zadawane atakującemu przy każdym otrzymanym ciosie)
@export var thorns_damage: int = 0

## Procent otrzymanych obrażeń (po redukcji przez pancerz) odbijanych w atakującego
@export_range(0.0, 1.0) var thorns_percent: float = 0.0

func _init() -> void:
	_initial_max_health = max_health

func get_total_armor() -> int:
	# TARCZA: Pancerz nie może spaść poniżej 0, zapobiega to wpadnięciu w ujemne wartości przy debuffach
	return max(0, int((base_armor + armor_adder) * armor_multiplier))

## Sprawdza, czy statystyki postaci zapewniają całkowitą odporność na podany efekt (SOLID).
func is_immune_to(effect: Effect) -> bool:
	if effect == null:
		return false

	var effective_cat: int = int(effect.get_effective_category())
	if effective_cat != int(Effect.EffectCategory.NONE):
		for immune_cat in immune_categories:
			if int(immune_cat) == effective_cat:
				return true

	if effect.effect_name != "":
		var incoming_name := effect.effect_name.to_lower().strip_edges()
		for immune_name in immune_effect_names:
			if String(immune_name).to_lower().strip_edges() == incoming_name:
				return true

	if cc_resistance >= FULL_RESISTANCE_THRESHOLD and effective_cat in [
		int(Effect.EffectCategory.STUN),
		int(Effect.EffectCategory.KNOCKBACK)
	]:
		return true

	return false

func is_alive() -> bool :
	return health > 0

func take_damage(damage : int, armor_penetration : float) -> void :
	# Pancerz jest redukowany o procent penetracji (np. 0.3 oznacza, że ignorujemy 30% pancerza)
	var effective_armor = float(get_total_armor()) * (1.0 - clampf(armor_penetration, 0.0, 1.0))
	var final_damage = damage - int(effective_armor)

	# Zabezpieczenie: cios zawsze zadaje co najmniej MIN_DAMAGE_AFTER_ARMOR (1 punkt obrażeń)
	final_damage = max(MIN_DAMAGE_AFTER_ARMOR, final_damage)

	health = max(0, health - final_damage)
	health_changed.emit(health, max_health) # Informujemy UI
	print("Otrzymano cios! Obrażenia bazowe: ", damage, " | Zablokowano: ", get_total_armor(), " | Otrzymano: ", final_damage)

	if health <= 0 :
		kill()

## Leczy postać o podaną wartość. Zwraca faktyczną ilość przywróconego HP.
## Jeśli silent == true, leczenie nie wywoła zielonego rozbłysku ekranu u gracza.
func heal(healing : int, silent : bool = false) -> int :
	if healing <= 0:
		return 0
	var old_health := health
	health = min(max_health, health + healing)
	var actual_healed := health - old_health

	# Informujemy UI i obserwatorów tylko, jeśli stan HP faktycznie uległ zmianie
	if actual_healed > 0:
		health_changed.emit(health, max_health)
		health_healed.emit(actual_healed, silent)
	return actual_healed

func heal_completely(silent : bool = true) -> void :
	var old_health := health
	health = max_health
	health_changed.emit(health, max_health)
	if health > old_health and not silent:
		health_healed.emit(health - old_health, silent)

func kill() -> void :
	health = 0
	health_changed.emit(health, max_health)
	died.emit() # Odpalamy sygnał śmierci!

func boost_max_health(boost : int) -> void :
	if boost > 0 :
		max_health += boost

func reduce_max_health(reduction : int) -> void :
	if reduction <= 0:
		return
	if max_health - reduction > 0 :
		max_health -= reduction
	# żeby zdrowie nie było większe niż limit:
	if health > max_health :
		heal_completely(true)

func reset_stats() -> void :
	max_health = _initial_max_health if _initial_max_health > 0 else DEFAULT_MAX_HEALTH
	heal_completely(true)
