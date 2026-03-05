# inventory.gd
extends Node
class_name Inventory

@export var max_items: int = 9 # Rozmiar Twojego ekwipunku
# Używamy typowanej tablicy dla bezpieczeństwa i podpowiedzi w edytorze
@export var items: Array[ItemData] = []

@export var current_item_index : int = 0

# Sygnał, który powiadomi UI o zmianie
signal inventory_updated

# Constructor
func _init() -> void :
	# Wszystkie miejsca będą na start miały wartość 'null' (pusty slot).
	items.resize(max_items)

func add_item(item: ItemData) -> bool:
	# Proste dodawanie do pierwszego wolnego slotu (jeśli zrobisz tablicę o stałym rozmiarze)
	# W tym przykładzie po prostu dodajemy na koniec listy
	items.append(item)
	inventory_updated.emit()
	return true

func remove_item(index: int) -> void:
	if index >= 0 and index < items.size():
		items.remove_at(index)
		inventory_updated.emit()

func get_item() -> ItemData :
	return items[current_item_index]

func select_item(index) -> void :
	current_item_index = index
	inventory_updated.emit()
