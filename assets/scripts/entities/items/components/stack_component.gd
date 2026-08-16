class_name StackComponent
extends ItemComponent

@export var max_stack: int = 100

## Ustawiamy domyślną ilość, gdy przedmiot jest tworzony po raz pierwszy
func initialize_state(item_instance: ItemInstance) -> void:
	if not item_instance.state.has("amount"):
		item_instance.state["amount"] = 1
