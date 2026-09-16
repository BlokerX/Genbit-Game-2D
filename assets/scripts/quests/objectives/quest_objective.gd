extends Resource
class_name QuestObjective

## Opis celu.
@export var objective_description: String = ""

## Funkcja sprawdzająca, czy wydarzenie ze świata (EventBus) pasuje do tego celu.
## Funkcja zwraca NOWY postęp.
func check_event(_event_type: String, _event_data: Dictionary, current_progress: int) -> int:
	return current_progress

## Zwraca ile punktów postępu jest wymagane do ukończenia celu (domyślnie 1)
func get_required_amount() -> int:
	return 1
