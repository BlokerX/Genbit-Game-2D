extends Resource
class_name ItemLootPool

@export var entries: Array[ItemLootEntry] = []

## Zwraca JEDEN losowy wpis (ItemLootEntry), typując go na podstawie wagi (Koło Fortuny)
func get_random_entry() -> ItemLootEntry:
	if entries.is_empty(): 
		return null
		
	var total_weight: float = 0.0
	for e in entries: 
		if e and e.item_data: 
			total_weight += e.weight
			
	if total_weight <= 0.0: 
		return null
	
	var roll = randf() * total_weight
	var current_weight: float = 0.0
	
	for e in entries:
		if e and e.item_data:
			current_weight += e.weight
			if roll <= current_weight:
				return e
				
	return null
