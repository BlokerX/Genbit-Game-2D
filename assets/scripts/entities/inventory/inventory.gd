# inventory.gd
extends Node
class_name Inventory

#region Inventory stats
## Rozmiar ekwipunku
@export var slots_amount: int = 9 

## Używamy typowanej tablicy dla bezpieczeństwa i podpowiedzi w edytorze
@export var slots: Array[SlotData] = []

## Aktualnie wybrany indeks slotu
@export var current_slot_index : int = 0

#endregion


#region Signals

## Sygnał, który powiadomi UI o zmianie
signal inventory_updated

signal item_dropped(item_data: ItemData, drop_amount: int)

#endregion

## PAMIĘĆ PODRĘCZNA DO CRAFTINGU (Format: { ID : Ilość })
var _item_count_cache: Dictionary = {}

## Constructor
func _init() -> void :
	# Wszystkie miejsca będą na start miały wartość 'null' (pusty slot).
	slots.resize(slots_amount)
	for i in range(slots_amount):
		slots[i] = SlotData.new() # Przygotowanie pustych pojemników

## Zbudowanie cache na start gry
func _ready() -> void:
	_rebuild_cache()

## Konsumpcja wytrzymałości itemu (zmniejszenie wytrzymałości)
func consume_durability_of_the_item() -> void:
	var slot = get_current_slot()
	
	if not slot.is_empty():
		# Zmniejszamy wytrzymałość o 1 użycie
		slot.reduce_durability()
		
		# Jeśli to był ostatni użytek, konsumujemy sztukę
		if slot.current_durability <= 0:
			consume_current_item()
			return
			
		# Informujemy UI o zmianie (żeby odświeżyło pasek durability)
		inventory_updated.emit()

## Konsumpcja sztuki itemu (zmniejszenie ilości w staku)
func consume_current_item() -> void:
	var slot = get_current_slot()
	
	if not slot.is_empty():
		var id = slot.item_data.item_id
		
		# Zmniejszamy ilość przedmiotów w stacku o 1
		slot.stack_amount -= 1
		_update_cache(id, -1) # Odświeżenie systemu craftingu
		
		# Jeśli to był ostatni przedmiot w tym slocie, czyścimy slot
		if slot.stack_amount <= 0:
			slot.item_data = null # Czyszczenie
		else :
			slot.repair_item() # Mechanizm wyciągania nowego przedmiotu!
			
		# Informujemy UI o zmianie (żeby odświeżyło cyferki stacków)
		inventory_updated.emit()

## Wyrzuca przedmiot z ekwipunku wywołując zdarzenie item_dropped z przesłaniem danych wyrzuconego przedmiotu
func drop_current_item(drop_all: bool = false) -> void:
	var slot = get_current_slot()
	
	if slot.is_empty(): return
	
	#Kopiujemy dane przedmiotu, żeby przekazać je do obiektu na ziemi
	#stare #var dropped_item_data = item.duplicate()
	var dropped_item = slot.item_data
	var amount_to_drop = slot.stack_amount if drop_all else 1
		
	if drop_all:
		_update_cache(dropped_item.item_id, -slot.stack_amount)
		
		# Jeśli wyrzucamy wszystko, przypisujemy pełną ilość i usuwamy cały stack ze slota
		slot.item_data = null
		slot.stack_amount = 0
		inventory_updated.emit()
	else:
		# Skoro wyrzucamy jedną sztukę, zużywamy 1 sztukę ze slota (to odświeży też UI)
		consume_current_item()
		
	# Informujemy świat (naszego gracza), że wyrzucono przedmiot, wysyłając mu dane
	item_dropped.emit(dropped_item, amount_to_drop)



func get_current_slot() -> SlotData :
	if slots != null and slots.size() > 0 and current_slot_index < slots.size():
		return slots[current_slot_index]
	else: return null

func get_current_item() -> ItemData :
	var slot = get_current_slot()
	if slot != null:
		return slot.item_data
	return null


## Pobranie itemu do ekwipunku
func add_item(item: ItemData, amount_to_add: int = 1) -> int:
	# Nic nie dodaliśmy, zwracamy 0
	if item == null or amount_to_add <= 0: return amount_to_add
	var remaining = amount_to_add
	
	# 1. Szukanie w stosach
	if item.item_is_stackable:
		for slot in slots:
			if not slot.is_empty() and slot.item_data.item_id == item.item_id and slot.item_data.item_name == item.item_name:
				var available_space = item.item_max_stack_count - slot.stack_amount
				
				if available_space > 0:
					var adding = min(remaining, available_space)
					slot.stack_amount += adding
					remaining -= adding
					_update_cache(item.item_id, adding)
					
					if remaining == 0:
						inventory_updated.emit()
						return 0
	
	# 2. Szukanie pustych w wybranej ręce (jak w Twoim oryginale)
	if slots[current_slot_index].is_empty():
		var adding = min(remaining, item.item_max_stack_count)
		slots[current_slot_index].set_item(item, adding)
		remaining -= adding
		_update_cache(item.item_id, adding)
		if remaining == 0:
			inventory_updated.emit()
			return 0

	# 3. Szukanie dowolnego pustego od lewej
	for slot in slots:
		if slot.is_empty():
			var adding = min(remaining, item.item_max_stack_count)
			slot.set_item(item, adding)
			remaining -= adding
			_update_cache(item.item_id, adding)
			if remaining == 0:
				inventory_updated.emit()
				return 0
				
	inventory_updated.emit()
	return remaining

## Usuwanie przedmiotu z ekwipunku
#func remove_item(index: int) -> void:
	#if index >= 0 and index < items.size():
		#items[index] = null # Zamiast remove_at(index), zostawia slot tylko z null zamiast usuwać go z listy
		#inventory_updated.emit()


## Zmienia aktualnie wybrany indeks aktualnego itemu (zmiana wybranego itemu)
func select_item(index) -> void :
	current_slot_index = index
	inventory_updated.emit()

## Obsługa wybierania poprzedniego i następnego indeksu
func scroll_inventory(direction: int) -> void:
	var new_index = current_slot_index + direction
	
	# Jeśli wyjdziemy poza prawo, wracamy na początek (0)
	if new_index >= slots.size():
		new_index = 0
	# Jeśli wyjdziemy poza lewo, idziemy na koniec
	elif new_index < 0:
		new_index = slots.size() - 1
		
	select_item(new_index)



# ----------------------------------------------------
# --- BEZPĘTLOWY SYSTEM CRAFTINGU O(1) ---
# ----------------------------------------------------

func get_item_amount(item_id: int) -> int:
	return _item_count_cache.get(item_id, 0)

func has_items(item_id: int, required_amount: int) -> bool:
	return get_item_amount(item_id) >= required_amount

func consume_ingredients(item_id: int, required_amount: int) -> void:
	var remaining = required_amount
	for slot in slots:
		if not slot.is_empty() and slot.item_data.item_id == item_id:
			var taking = min(slot.stack_amount, remaining)
			slot.stack_amount -= taking
			remaining -= taking
			_update_cache(item_id, -taking)
			
			if slot.stack_amount <= 0:
				slot.item_data = null
				
			if remaining <= 0: break
			
	inventory_updated.emit()

func _update_cache(item_id: int, diff: int) -> void:
	if not _item_count_cache.has(item_id):
		_item_count_cache[item_id] = 0
	_item_count_cache[item_id] += diff

## Funkcja odbudowująca cache po ręcznym załadowaniu przedmiotów
func _rebuild_cache() -> void:
	_item_count_cache.clear()
	for slot in slots:
		if not slot.is_empty():
			_update_cache(slot.item_data.item_id, slot.stack_amount)
