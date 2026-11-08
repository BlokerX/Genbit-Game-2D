extends Resource
class_name GuaranteedLootEntry

@export var item_data: ItemData
@export var amount: int = 1

@export_group("Opcje Skrzyni")
## Zostaw -1, aby gra wrzuciła przedmiot w pierwsze wolne miejsce.
## Wpisz 0 lub więcej (np. 0, 1, 2), aby wymusić umieszczenie w konkretnej kratce.
@export var target_slot: int = -1

## Tworzy gotową instancję gwarantowanego przedmiotu z pełną wytrzymałością początkową.
func create_item_instance() -> ItemInstance:
	if item_data == null:
		return null
	var temp_entry: ItemLootEntry = ItemLootEntry.new()
	temp_entry.item_data = item_data
	return temp_entry.create_item_instance(maxi(1, amount))
