# inventory.gd
extends Node
class_name Inventory

# Zmienna, do której przeciągniemy naszą scenę item_pickup.tscn
@export var item_pickup_scene: PackedScene

@export var max_items: int = 9 # Rozmiar Twojego ekwipunku
# Używamy typowanej tablicy dla bezpieczeństwa i podpowiedzi w edytorze
@export var items: Array[ItemData] = []

@export var current_item_index : int = 0

# Sygnał, który powiadomi UI o zmianie
signal inventory_updated

# Zamiast referencji do item_pickup_scene dodaj sygnał
signal item_dropped(item_data: ItemData)

# Constructor
func _init() -> void :
	# Wszystkie miejsca będą na start miały wartość 'null' (pusty slot).
	items.resize(max_items)

func add_item(item: ItemData) -> int:
	if item == null:
		return 0 # Nic nie dodaliśmy, zwracamy 0
		
	var item_to_add = item.duplicate()

	# 1. ETAP: Upchanie do stacków
	if item_to_add.item_is_stackable:
		for i in range(items.size()):
			if items[i] != null and items[i].item_id == item_to_add.item_id:
				var available_space = items[i].item_max_stack_count - items[i].item_stack_count
				
				if available_space > 0:
					if item_to_add.item_stack_count <= available_space:
						items[i].item_stack_count += item_to_add.item_stack_count
						inventory_updated.emit()
						return 0 # Zmieściło się wszystko, zostaje 0 reszty na ziemi!
					else:
						items[i].item_stack_count = items[i].item_max_stack_count
						item_to_add.item_stack_count -= available_space

	# 2. ETAP: Szukanie pustych slotów dla reszty
	if items[current_item_index] == null:
		items[current_item_index] = item_to_add
		inventory_updated.emit()
		return 0 # Przedmiot wskoczył prosto do wolnej ręki!

	# Jeśli slot w ręce był jednak zajęty, szukamy pierwszego wolnego slota w plecaku od lewej (stara logika)
	for i in range(items.size()):
		if items[i] == null:
			items[i] = item_to_add 
			inventory_updated.emit()
			return 0

	# 3. ETAP: Zabrakło miejsca! Ekwipunek pełny.
	# Ale UWAGA: Mogliśmy dodać część przedmiotów w ETAPIE 1, więc musimy odświeżyć UI!
	inventory_updated.emit()
	print("Ekwipunek jest pełny! Na ziemi zostało sztuk: ", item_to_add.item_stack_count)
	
	# Zwracamy ile sztuk przedmiotu fizycznie nie zmieściło się do plecaka
	return item_to_add.item_stack_count

func consume_current_item() -> void:
	var item = get_current_item()
	
	if item != null:
		# Zmniejszamy ilość przedmiotów w stacku o 1
		item.item_stack_count -= 1
		
		# Jeśli to był ostatni przedmiot w tym slocie, czyścimy slot
		if item.item_stack_count <= 0:
			items[current_item_index] = null
		else :
			item.repair_item()
			
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
		items[index] = null # Zamiast remove_at(index), zostawia slot tylko z null zamiast usuwać go z listy
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

func _physics_process(_delta) :
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
	
	# NOWE: Wyrzucanie przedmiotu
	if Input.is_action_just_pressed("DropItem"):
		drop_current_item()

func drop_current_item() -> void:
	var item = get_current_item()
	
	if item != null and item_pickup_scene != null:
		# 1. Tworzymy nowy fizyczny obiekt przedmiotu z naszej sceny
		var drop = item_pickup_scene.instantiate()
		
		# 2. Kopiujemy dane przedmiotu, żeby przekazać je do obiektu na ziemi
		var dropped_item_data = item.duplicate()
		dropped_item_data.item_stack_count = 1 # Wyrzucamy tylko 1 sztukę na raz
		drop.item_data = dropped_item_data
		
		# 3. Dodajemy obiekt do głównego świata gry (nie do gracza!)
		# get_tree().current_scene odnosi się do głównego węzła aktualnej mapy
		get_tree().current_scene.add_child(drop)
		
		# 4. Ustawiamy pozycję przedmiotu na ziemi.
		# Ponieważ skrypt Inventory jest dzieckiem Gracza, get_parent() to Gracz.
		# Dodajemy losowe przesunięcie, żeby przedmiot nie pojawił się idealnie 
		# w graczu (co mogłoby spowodować jego natychmiastowe, ponowne podniesienie!)
		var random_offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		drop.global_position = get_parent().global_position + random_offset
		
		# 5. Skoro przedmiot wyleciał z ekwipunku, zużywamy 1 sztukę ze slota
		consume_current_item()
		
		# 6. Informujemy świat, że przedmiot został wyrzucony z tego plecaka
		item_dropped.emit(dropped_item_data)
