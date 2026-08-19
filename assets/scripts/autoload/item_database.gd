extends Node

## Słownik przechowujący załadowane przedmioty (Klucz: StringName, Wartość: ItemData)
var items: Dictionary = {}

func _ready() -> void:
	# Automatycznie skanujemy Twój folder z przedmiotami przy starcie gry!
	load_all_items("res://assets/data/items/")

func load_all_items(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_error("ItemDatabase: Nie można otworzyć folderu: " + path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	# Skanowanie i ładowanie (odporne na .remap w wyeksportowanej grze)
	while file_name != "":
		if not dir.current_is_dir():
			var clean_name = file_name.replace(".remap", "")
			if clean_name.ends_with(".tres"):
				var resource = ResourceLoader.load(path.path_join(clean_name))
				if resource is ItemData:
					register_item(resource, path.path_join(clean_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	
	print("ItemDatabase: Pomyślnie załadowano ", items.size(), " unikalnych przedmiotów.")

func register_item(item: ItemData, file_path: String) -> void:
	if item.item_id == null or str(item.item_id) == "":
		push_error("BŁĄD: Przedmiot w pliku " + file_path + " nie ma ustawionego item_id!")
		return
		
	# TARCZA OCHRONNA: Weryfikacja duplikatów!
	if items.has(item.item_id):
		push_error("BŁĄD KRYTYCZNY: Znaleziono zduplikowane ID przedmiotu: '" + str(item.item_id) + "'! Plik: " + file_path)
		assert(false, "Zduplikowane ID przedmiotu! Sprawdź konsolę.") # Zatrzymuje grę w Edytorze
		return
		
	items[item.item_id] = item

## Funkcja do pobierania szablonu przedmiotu z dowolnego miejsca w kodzie
func get_item(id: StringName) -> ItemData:
	return items.get(id, null)
