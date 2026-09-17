extends Resource
class_name AIAbility

@export var ability_name: String = "Special Ability"
@export var cooldown: float = 5.0
@export var min_range: float = 0.0
@export var max_range: float = 200.0

@export_category("Inteligencja i Wyjątki")
## O ile sekund AI musi być w aktywnej walce, zanim rzuci ten czar po raz pierwszy?
## Zapobiega to używaniu potężnych ataków w ułamku sekundy po zauważeniu gracza.
@export var first_cast_delay: float = 5.0
## Szansa na rzucenie czaru, gdy jest gotowy (np. 0.6 = 60%).
## Jeśli AI oblało rzut, odczeka ułamek sekundy przed kolejną próbą (wahanie).
@export_range(0.0, 1.0) var cast_chance: float = 0.7 
## Jeśli włączone, AI może rzucić tę umiejętność NAWET jeśli inna jest aktualnie wykonywana.
@export var ignore_global_cast_lock: bool = false

## Zwraca true, jeśli zdolność jest gotowa do użycia (sprawdza dystans i warunki specjalne).
func check_conditions(attacker: CharacterEntity, target: CharacterEntity, distance: float) -> bool:
	if distance < min_range or distance > max_range:
		return false
	return true

## Główna logika umiejętności, nadpisywana w konkretnych plikach.
func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	pass
