extends QuestObjective
class_name ObjectiveGather

@export var required_item: ItemData
@export var required_amount: int = 1

func check_event(event_type: String, event_data: Dictionary) -> int:
	if event_type == "item_collected" and required_item != null:
		# Jeśli gracz podniósł przedmiot i jego ID zgadza się z naszym wymogiem
		if event_data.get("item_id") == required_item.item_id:
			# Dodajemy do postępu tyle sztuk, ile gracz podniósł na raz
			return event_data.get("amount", 1) 
	return 0

func get_required_amount() -> int:
	return required_amount
