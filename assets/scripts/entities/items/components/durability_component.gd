class_name DurabilityComponent
extends ItemComponent

@export var max_durability: int = 1

## Ustawiamy domyślną wytrzymałość na maksymalną przy tworzeniu przedmiotu
func initialize_state(item_instance: ItemInstance) -> void:
	if not item_instance.state.has("durability"):
		item_instance.state["durability"] = max_durability
