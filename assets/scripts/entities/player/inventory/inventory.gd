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

func get_current_item() -> ItemData :
	# Sprawdzamy, czy indeks jest bezpieczny (nie jest na minusie i jest mniejszy niż rozmiar tablicy)
	if current_item_index >= 0 and current_item_index < items.size():
		return items[current_item_index]
	
	# Jeśli indeks jest zły, zwracamy null (brak przedmiotu), zamiast crashować grę
	#print("Błąd: Próba pobrania przedmiotu spoza zakresu ekwipunku!")
	return null

func select_item(index) -> void :
	current_item_index = index
	inventory_updated.emit()

func _physics_process(delta) :
	if Input.is_action_just_pressed("InventorySlot1") :
		select_item(0)
	elif Input.is_action_just_pressed("InventorySlot2") :
		select_item(1)
	elif Input.is_action_just_pressed("InventorySlot3") :
		select_item(2)
	elif Input.is_action_just_pressed("InventorySlot4") :
		select_item(3)
	elif Input.is_action_just_pressed("InventorySlot5") :
		select_item(4)
	elif Input.is_action_just_pressed("InventorySlot6") :
		select_item(5)
	elif Input.is_action_just_pressed("InventorySlot7") :
		select_item(6)
	elif Input.is_action_just_pressed("InventorySlot8") :
		select_item(7)
	elif Input.is_action_just_pressed("InventorySlot9") :
		select_item(8)
