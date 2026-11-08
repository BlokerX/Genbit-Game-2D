extends Node
class_name DevChestFiller

@export_group("Konfiguracja Dev Chest")
## Ścieżka do folderu, w którym trzymasz pliki .tres przedmiotów (używana jako fallback, jeśli ItemDatabase jest puste).
@export_dir var items_directory: String = "res://assets/data/items/"

## Ilość sztuk każdego przedmiotu w skrzyni. 
@export var default_items_amount: int = 999

## Referencja do komponentu magazynu (jeśli puste, skrypt poszuka go u rodzica)
@export var storage_component: StorageComponent

func _ready() -> void:
	call_deferred("_fill_chest")

func _fill_chest() -> void:
	if not storage_component:
		storage_component = get_parent().get_node_or_null("StorageComponent") as StorageComponent

	if not storage_component:
		push_error("DevChestFiller: Nie znaleziono węzła StorageComponent obok wypełniacza!")
		return

	var loaded_items: Array[ItemData] = []

	# 1. OPTYMALIZACJA O(1): Pobieramy już wczytane przedmioty bezpośrednio z globalnego ItemDatabase
	# zamiast skanować dysk i wywoływać ResourceLoader.load() dla każdej skrzyni deweloperskiej z osobna!
	if ItemDatabase != null and not ItemDatabase.items.is_empty():
		for item_res in ItemDatabase.items.values():
			if item_res is ItemData:
				loaded_items.append(item_res as ItemData)
	else:
		var dir: DirAccess = DirAccess.open(items_directory)
		if not dir:
			push_error("DevChestFiller: Nie można otworzyć folderu: " + items_directory)
			return
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name: String = file_name.replace(".remap", "")
				if clean_name.ends_with(".tres"):
					var resource: Resource = ResourceLoader.load(items_directory.path_join(clean_name))
					if resource is ItemData:
						loaded_items.append(resource as ItemData)
			file_name = dir.get_next()
		dir.list_dir_end()

	# 2. SORTOWANIE PO ID
	loaded_items.sort_custom(func(a: ItemData, b: ItemData): return a.item_id < b.item_id)

	# 3. NADPISYWANIE MAGAZYNU
	storage_component.slots_amount = loaded_items.size()
	storage_component.slots.clear()
	storage_component.slots.resize(storage_component.slots_amount)

	# 4. WYPEŁNIANIE SLOTÓW (Wzorzec Flyweight: współdzielimy niemodyfikowalny szablon ItemData, oszczędzając setki MB RAM!)
	for i in range(storage_component.slots_amount):
		if default_items_amount == 0 or default_items_amount < -1:
			storage_component.slots[i] = SlotData.new()
			continue

		var new_slot: SlotData = SlotData.new()
		var item_instance: ItemInstance = ItemInstance.new(loaded_items[i], default_items_amount)

		if item_instance.data and item_instance.data.components != null:
			for comp in item_instance.data.components:
				if comp is DurabilityComponent:
					item_instance.state["durability"] = comp.max_durability
					break

		new_slot.item = item_instance
		storage_component.slots[i] = new_slot

	print("DevChestFiller: Pomyślnie załadowano ", storage_component.slots_amount, " przedmiotów (Ilość w stacku: ", default_items_amount, ").")
