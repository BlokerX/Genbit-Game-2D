extends Resource
class_name QuestObjective

@export var objective_description: String = "Zrób coś"

## Funkcja sprawdzająca, czy wydarzenie ze świata (EventBus) pasuje do tego celu.
## Zwraca liczbę punktów postępu do dodania (np. 1, jeśli zabiliśmy 1 odpowiedniego wroga).
func check_event(_event_type: String, _event_data: Dictionary) -> int:
	return 0
	
## Zwraca ile punktów postępu jest wymagane do ukończenia celu (domyślnie 1)
func get_required_amount() -> int:
	return 1
