extends QuestObjective
class_name ObjectiveAction

@export var required_action: String = "" ## np. fire_pistol
@export var required_amount: int = 1

func check_event(event_type: String, event_data: Dictionary) -> int:
	# Sprawdzamy czy to wydarzenie typu "Akcja" i czy nazwa akcji się zgadza
	if event_type == "action_performed" and event_data.get("action_name") == required_action:
		return 1 # Dodajemy 1 do postępu questa!
	return 0

func get_required_amount() -> int:
	return required_amount
