extends Resource
class_name ItemLootPool

@export var entries: Array[ItemLootEntry] = []

## Zwraca całkowicie gotową, nową INSTANCJĘ przedmiotu do włożenia w skrzynię lub na ziemię
func get_random_item_instance() -> ItemInstance:
	if entries.is_empty(): return null
	var total_weight: float = 0.0
	for e in entries: if e and e.item_data: total_weight += e.weight
	if total_weight <= 0.0: return null
	
	var roll = randf() * total_weight
	var current_weight: float = 0.0
	for e in entries:
		if e and e.item_data:
			current_weight += e.weight
			if roll <= current_weight:
				var unique_data = e.item_data.duplicate(true)
				return ItemInstance.new(unique_data, randi_range(e.min_amount, e.max_amount))
	return null
