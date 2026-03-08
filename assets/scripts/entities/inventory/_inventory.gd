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
	# Przeszukujemy ekwipunek w poszukiwaniu pierwszego wolnego miejsca (null)
	for i in range(items.size()):
		if items[i] == null:
			# Klonujemy zasób, by przedmioty (np. ich wytrzymałość) działały niezależnie
			items[i] = item.duplicate() 
			inventory_updated.emit()
			return true
			
	print("Ekwipunek jest pełny!")
	return false

func consume_current_item() -> void:
	var item = get_current_item()
	
	if item != null:
		# Zmniejszamy ilość przedmiotów w stacku o 1
		item.item_stack_count -= 1
		
		# Jeśli to był ostatni przedmiot w tym slocie, czyścimy slot
		if item.item_stack_count <= 0:
			items[current_item_index] = null
			
		# Informujemy UI o zmianie (żeby odświeżyło cyferki stacków)
		inventory_updated.emit()

func consume_durability_of_the_item() -> void:
	var item = get_current_item()
	
	if item != null:
		# Zmniejszamy wytrzymałość o 1 użycie
		item.reduce_durability()
		
		# Jeśli to był ostatni użytek, konsumujemy sztukę
		if item.durable <= 0:
			consume_current_item()
			return
			
		# Informujemy UI o zmianie (żeby odświeżyło pasek durability)
		inventory_updated.emit()

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

func scroll_inventory(direction: int) -> void:
	var new_index = current_item_index + direction
	
	# Jeśli wyjdziemy poza prawo, wracamy na początek (0)
	if new_index >= items.size():
		new_index = 0
	# Jeśli wyjdziemy poza lewo, idziemy na koniec
	elif new_index < 0:
		new_index = items.size() - 1
		
	select_item(new_index)

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
		
	elif Input.is_action_just_pressed("InventoryScrollDown"):
		scroll_inventory(1)
	elif Input.is_action_just_pressed("InventoryScrollUp"):
		scroll_inventory(-1)
