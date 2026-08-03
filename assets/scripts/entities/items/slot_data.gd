extends Resource
class_name SlotData

#signal slot_emptied()

## Zamiast trzymać 3 zmienne, trzymamy po prostu odniesienie do jednej instancji!
@export var item: ItemInstance = null

func set_item_data(new_item: ItemData, new_stack_amount: int = 1) -> void:
	# ZABEZPIECZENIE: Zawsze tworzymy głęboką kopię danych, 
	# aby uniknąć współdzielenia referencji z plikiem .tres na dysku
	var unique_item_data = new_item.duplicate(true)
	
	# Tworzymy nową instancję i wkładamy do szuflady
	item = ItemInstance.new(unique_item_data, new_stack_amount)

## Kompleksowo czyści wszystkie informacje w slocie
func clear_slot() -> void:
	item = null

# Mały dodatek dla wygody
func is_empty() -> bool:
	return item == null or item.data == null or item.amount <= 0
