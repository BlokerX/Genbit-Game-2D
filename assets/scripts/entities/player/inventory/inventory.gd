# inventory.gd
extends Node
class_name Inventory

# Używamy typowanej tablicy dla bezpieczeństwa i podpowiedzi w edytorze
@export var items: Array[ItemData] = []

# Sygnał, który powiadomi UI o zmianie
signal inventory_updated

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
