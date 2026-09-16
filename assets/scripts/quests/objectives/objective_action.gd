extends QuestObjective
class_name ObjectiveAction

@export var required_action: String = "" ## np. fire_pistol
@export var required_amount: int = 1

func check_event(event_type: String, event_data: Dictionary, current_progress: int) -> int:
	if event_type == "action_performed" and event_data.get("action_name") == required_action:
		return current_progress + 1 # Zwiększamy postęp o 1
	return current_progress

func get_required_amount() -> int:
	return required_amount
