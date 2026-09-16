extends QuestObjective
class_name ObjectiveGather

@export_group("Wymagania")
## Przeciągnij tutaj przedmiot, który gracz musi zebrać (np. Pistolet)
@export var required_item: ItemData
## Ile sztuk musi zebrać?
@export var required_amount: int = 1

func check_event(event_type: String, event_data: Dictionary, current_progress: int) -> int:
	# Nasłuchujemy przeliczenia ekwipunku
	if event_type == "inventory_changed" and required_item != null:
		var inv: Inventory = event_data.get("inventory")
		if inv != null:
			# Korzystamy z Twojej funkcji O(1), żeby błyskawicznie sprawdzić ile masz sztuk!
			return inv.get_item_amount(required_item.item_id)
			
	return current_progress

func get_required_amount() -> int:
	return required_amount
