# inventory.gd
extends Node
class_name Inventory

#region Inventory stats
## Rozmiar ekwipunku
@export var max_items: int = 9 

## Używamy typowanej tablicy dla bezpieczeństwa i podpowiedzi w edytorze
@export var items: Array[ItemData] = []

## Aktualnie wybrany indeks slotu
@export var current_item_index : int = 0

#endregion


#region Signals

## Sygnał, który powiadomi UI o zmianie
signal inventory_updated

signal item_dropped(item_data: ItemData)

#endregion

## Constructor
func _init() -> void :
	# Wszystkie miejsca będą na start miały wartość 'null' (pusty slot).
	items.resize(max_items)


## Zwraca aktualnie wybrany przedmiot
func get_current_item() -> ItemData :
	# Sprawdzamy, czy indeks jest bezpieczny (nie jest na minusie i jest mniejszy niż rozmiar tablicy)
	if current_item_index >= 0 and current_item_index < items.size():
		return items[current_item_index]
	
	# Jeśli indeks jest zły, zwracamy null (brak przedmiotu), zamiast crashować grę
	#debug
	print("Błąd: Próba pobrania przedmiotu spoza zakresu ekwipunku!")
	#endif
	return null


## Pobranie itemu do ekwipunku
func add_item(item: ItemData) -> int:
	# Nic nie dodaliśmy, zwracamy 0
	if item == null:
		return 0
	
	# Duplikacja itemu ponieważ fizyczny egzemplarz będzie niszczony
	var item_to_add = item.duplicate()
	
	# 1. Upchanie do stacków
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
	
	# 2. Szukanie pustych slotów dla reszty
	
	# Jeśli wybrana wolna ręka to przedmiot wskoczy prosto do wolnej ręki!
	if items[current_item_index] == null:
		items[current_item_index] = item_to_add
		inventory_updated.emit()
		return 0 

	# Jeśli slot w ręce był jednak zajęty, szukamy pierwszego wolnego slota w plecaku od lewej
	for i in range(items.size()):
		if items[i] == null:
			items[i] = item_to_add 
			inventory_updated.emit()
			return 0

	# 3. Zabrakło miejsca! Ekwipunek pełny.
	# Ale UWAGA: Mogliśmy dodać część przedmiotów w ETAPIE 1, więc musimy odświeżyć UI!
	inventory_updated.emit()
	print("Ekwipunek jest pełny! Na ziemi zostało sztuk: ", item_to_add.item_stack_count)
	
	# Zwracamy ile sztuk przedmiotu fizycznie nie zmieściło się do plecaka
	return item_to_add.item_stack_count

## Usuwanie przedmiotu z ekwipunku
func remove_item(index: int) -> void:
	if index >= 0 and index < items.size():
		items[index] = null # Zamiast remove_at(index), zostawia slot tylko z null zamiast usuwać go z listy
		inventory_updated.emit()


## Konsumpcja wytrzymałości itemu (zmniejszenie wytrzymałości)
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

## Konsumpcja sztuki itemu (zmniejszenie ilości w staku)
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


## Zmienia aktualnie wybrany indeks aktualnego itemu (zmiana wybranego itemu)
func select_item(index) -> void :
	current_item_index = index
	inventory_updated.emit()

## Obsługa wybierania poprzedniego i następnego indeksu
func scroll_inventory(direction: int) -> void:
	var new_index = current_item_index + direction
	
	# Jeśli wyjdziemy poza prawo, wracamy na początek (0)
	if new_index >= items.size():
		new_index = 0
	# Jeśli wyjdziemy poza lewo, idziemy na koniec
	elif new_index < 0:
		new_index = items.size() - 1
		
	select_item(new_index)



## Wyrzuca przedmiot z ekwipunku wywołując zdarzenie item_dropped z przesłaniem danych wyrzuconego przedmiotu
func drop_current_item() -> void:
	var item = get_current_item()
	
	if item != null:
		#Kopiujemy dane przedmiotu, żeby przekazać je do obiektu na ziemi
		var dropped_item_data = item.duplicate()
		dropped_item_data.item_stack_count = 1 # Wyrzucamy tylko 1 sztukę na raz
		
		# Skoro wyrzucamy, zużywamy 1 sztukę ze slota (to odświeży też UI)
		consume_current_item()
		
		# Informujemy świat (naszego gracza), że wyrzucono przedmiot, wysyłając mu dane
		item_dropped.emit(dropped_item_data)
