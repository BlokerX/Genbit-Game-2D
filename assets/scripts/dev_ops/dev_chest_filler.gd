extends Node
class_name DevChestFiller

@export_group("Konfiguracja Dev Chest")
## Ścieżka do folderu, w którym trzymasz pliki .tres przedmiotów
@export_dir var items_directory: String = "res://assets/data/items/"

## Ilość sztuk każdego przedmiotu w skrzyni. 
## Zgodnie z Twoim skryptem ItemInstance, wartość -1 da nieskończony stack!
@export var default_items_amount: int = 1

## Referencja do komponentu magazynu (jeśli puste, skrypt poszuka go u rodzica)
@export var storage_component: StorageComponent

func _ready() -> void:
	# Używamy call_deferred, aby mieć 100% pewności, że StorageComponent 
	# zdążył się już utworzyć i wywołać swojego własnego _ready()
	call_deferred("_fill_chest")

func _fill_chest() -> void:
	# Szukamy komponentu, jeśli go nie podpięto w edytorze
	if not storage_component:
		storage_component = get_parent().get_node_or_null("StorageComponent")
		
	if not storage_component:
		push_error("DevChestFiller: Nie znaleziono węzła StorageComponent obok wypełniacza!")
		return

	# Otwieramy folder z przedmiotami
	var dir = DirAccess.open(items_directory)
	if not dir:
		push_error("DevChestFiller: Nie można otworzyć folderu: " + items_directory)
		return
		
	var loaded_items: Array[ItemData] = []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	# 1. SKANOWANIE FOLDERU (Odporne na błędy wyeksportowanej gry)
	while file_name != "":
		if not dir.current_is_dir():
			# Zabezpieczenie na wyeksportowaną grę (usuwamy kompresję .remap z nazwy)
			var clean_name = file_name.replace(".remap", "")
			
			if clean_name.ends_with(".tres"):
				# Bezpieczne ładowanie zasobu z dysku
				var resource = ResourceLoader.load(items_directory.path_join(clean_name))
				if resource is ItemData:
					loaded_items.append(resource)
					
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# 2. SORTOWANIE PO ID
	loaded_items.sort_custom(func(a: ItemData, b: ItemData): return a.item_id < b.item_id)
	
	# 3. NADPISYWANIE MAGAZYNU
	# Narzucamy magazynowi nowy rozmiar na bazie tego, co znaleźliśmy
	storage_component.slots_amount = loaded_items.size()
	storage_component.slots.clear()
	storage_component.slots.resize(storage_component.slots_amount)
	
	# 4. WYPEŁNIANIE SLOTÓW
	for i in range(storage_component.slots_amount):
		
		# Jeśli ktoś wpisał 0 (lub mniej, ale nie -1), ignorujemy dodawanie przedmiotu
		if default_items_amount == 0 or default_items_amount < -1:
			storage_component.slots[i] = SlotData.new()
			continue
			
		var new_slot = SlotData.new()
		
		# --- KLUCZOWA ZMIANA: Przekazujemy wybraną ilość zamiast sztywnej '1' ---
		var item_instance = ItemInstance.new(loaded_items[i].duplicate(true), default_items_amount)
		
		# Naprawiamy zużycie, jeśli przedmiot ma wytrzymałość
		if item_instance.data and item_instance.data.max_durable > 0:
			item_instance.durability = item_instance.data.max_durable
			
		new_slot.item = item_instance
		storage_component.slots[i] = new_slot
		
	print("DevChestFiller: Pomyślnie załadowano ", storage_component.slots_amount, " przedmiotów (Ilość w stacku: ", default_items_amount, ").")
