extends Resource
class_name SlotData

## Zamiast trzymać 3 zmienne, trzymamy po prostu odniesienie do jednej instancji!
@export var item: ItemInstance = null

func set_item_data(new_item: ItemData, new_stack_amount: int = 1) -> void:
	# ZABEZPIECZENIE: Tworzymy lekką kopię danych i statystyk (bez klonowania tekstur/audio w RAM),
	# aby umożliwić indywidualne ulepszanie konkretnego egzemplarza przedmiotu!
	var unique_item_data: ItemData = new_item.create_unique_copy() if new_item != null else null
	item = ItemInstance.new(unique_item_data, new_stack_amount)

## Kompleksowo czyści wszystkie informacje w slocie
func clear_slot() -> void:
	item = null

func is_empty() -> bool:
	return item == null or item.data == null or item.state.get("amount", 0) <= 0
