extends Resource
class_name AIAbility

@export var ability_name: String = "Special Ability"
@export var cooldown: float = 5.0
@export var min_range: float = 0.0
@export var max_range: float = 200.0

## Zwraca true, jeśli zdolność jest gotowa do użycia (sprawdza dystans i warunki specjalne).
func check_conditions(attacker: CharacterEntity, target: CharacterEntity, distance: float) -> bool:
	if distance < min_range or distance > max_range:
		return false
	return true

## Główna logika umiejętności, nadpisywana w konkretnych plikach.
func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	pass
