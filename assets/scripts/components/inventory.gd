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

signal item_dropped(dropped_instance: ItemInstance, is_thrown: bool)

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


# ----------------------------------------------------
# --- ZUŻYWANIE PRZEDMIOTÓW ---
# ----------------------------------------------------

## Konsumpcja wytrzymałości itemu (zmniejszenie wytrzymałości)
func consume_durability_of_the_item() -> void:
	var slot = get_current_slot()
	if not slot.is_empty():
		slot.item.reduce_durability()
		
		# Jeśli wytrzymałość w instancji spadła do zera, niszczymy sztukę obecną
		if slot.item.durability == 0:
			consume_current_item()
			
		inventory_updated.emit()

## Konsumpcja sztuki itemu (zmniejszenie ilości w staku)
func consume_current_item() -> void:
	var slot = get_current_slot()
	if not slot.is_empty():
		var id = slot.item.data.item_id
		slot.item.amount -= 1
		_update_cache(id, -1) 
		
		if slot.item.amount <= 0:
			slot.clear_slot()
		else :
			slot.item.repair_item() # Mechanizm wyciągania nowego przedmiotu!
			
		# Informujemy UI o zmianie (żeby odświeżyło cyferki stacków)
		inventory_updated.emit()


# ----------------------------------------------------
# --- WYRZUCANIE I PODNOSZENIE ---
# ----------------------------------------------------

## Wyrzuca przedmiot z ekwipunku wywołując zdarzenie item_dropped z przesłaniem danych wyrzuconego przedmiotu
func drop_current_item(drop_all: bool = false) -> void:
	var slot = get_current_slot()
	if slot.is_empty(): return
	
	var instance_to_drop: ItemInstance
		
	if drop_all:
		# Wyrzucamy całą instancję, wyciągając ją prosto ze slota!
		instance_to_drop = slot.item
		_update_cache(instance_to_drop.data.item_id, -instance_to_drop.amount)
		slot.clear_slot()
		inventory_updated.emit()
	else:
		# Klonujemy instancję dla jednej sztuki, by zachować jej stan (durability itp.)
		instance_to_drop = ItemInstance.new(slot.item.data, 1)
		instance_to_drop.durability = slot.item.durability
		consume_current_item()
		
	# Informujemy świat, wysyłając CAŁĄ INSTANCJĘ
	item_dropped.emit(instance_to_drop, true)

## Przyjmuje istniejącą instancję z mapy (np. zużyty miecz lub połączone stosy łupu)
func add_instance(instance_to_add: ItemInstance) -> ItemInstance:
	if instance_to_add == null or instance_to_add.amount <= 0: 
		return null
		
	# Jeśli przedmiot z ziemi jest stackowalny, próbujemy uzupełnić istniejące stosy
	if instance_to_add.data.item_is_stackable:
		for slot in slots:
			if not slot.is_empty() and slot.item.data.item_id == instance_to_add.data.item_id:
				var available_space = instance_to_add.data.item_max_stack_count - slot.item.amount
				if available_space > 0:
					var adding = min(instance_to_add.amount, available_space)
					slot.item.amount += adding
					instance_to_add.amount -= adding
					_update_cache(instance_to_add.data.item_id, adding)
					
					if instance_to_add.amount <= 0:
						inventory_updated.emit()
						return null # Całość się zmieściła

	# Próbujemy wrzucić resztę lub całą broń do slotu trzymanego w dłoni
	if slots[current_slot_index].is_empty():
		slots[current_slot_index].item = instance_to_add
		_update_cache(instance_to_add.data.item_id, instance_to_add.amount)
		inventory_updated.emit()
		return null
		
	# Szukamy jakiegokolwiek innego pustego slota
	for slot in slots:
		if slot.is_empty():
			slot.item = instance_to_add 
			_update_cache(instance_to_add.data.item_id, instance_to_add.amount)
			inventory_updated.emit()
			return null
			
	# Brak miejsca - zwracamy instancję z powrotem
	return instance_to_add

## Klasyczne tworzenie nowego przedmiotu z definicji (przydatne np. w rzemiośle)
func add_item(item: ItemData, amount_to_add: int = 1) -> int:
	if item == null or amount_to_add <= 0: return amount_to_add
	var remaining = amount_to_add
	
	# 1. Szukanie w stosach
	if item.item_is_stackable:
		for slot in slots:
			if not slot.is_empty() and slot.item.data.item_id == item.item_id and slot.item.data.item_name == item.item_name:
				var available_space = item.item_max_stack_count - slot.item.amount
				
				if available_space > 0:
					var adding = min(remaining, available_space)
					slot.item.amount += adding
					remaining -= adding
					_update_cache(item.item_id, adding)
					
					if remaining == 0:
						inventory_updated.emit()
						return 0
	
	# 2. Szukanie pustych w wybranej ręce
	if slots[current_slot_index].is_empty():
		var adding = min(remaining, item.item_max_stack_count) if item.item_is_stackable else 1
		slots[current_slot_index].set_item_data(item, adding)
		remaining -= adding
		_update_cache(item.item_id, adding)
		if remaining == 0:
			inventory_updated.emit()
			return 0

	# 3. Szukanie dowolnego pustego od lewej
	for slot in slots:
		if slot.is_empty():
			var adding = min(remaining, item.item_max_stack_count) if item.item_is_stackable else 1
			slot.set_item_data(item, adding)
			remaining -= adding
			_update_cache(item.item_id, adding)
			if remaining == 0:
				inventory_updated.emit()
				return 0
				
	inventory_updated.emit()
	return remaining


# ----------------------------------------------------
# --- NAWIGACJA ---
# ----------------------------------------------------

func get_current_slot() -> SlotData :
	if slots != null and slots.size() > 0 and current_slot_index < slots.size():
		return slots[current_slot_index]
	else: return null

func get_current_item() -> ItemInstance :
	var slot = get_current_slot()
	if slot != null:
		return slot.item
	return null

## Zmienia aktualnie wybrany indeks aktualnego itemu (zmiana wybranego itemu)
func select_item(index) -> void :
	current_slot_index = index
	inventory_updated.emit()

## Obsługa wybierania poprzedniego i następnego indeksu
func scroll_inventory(direction: int) -> void:
	var new_index = wrapi(current_slot_index - direction, 0, slots.size())
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
		if not slot.is_empty() and slot.item.data.item_id == item_id:
			var taking = min(slot.item.amount, remaining)
			slot.item.amount -= taking
			remaining -= taking
			_update_cache(item_id, -taking)
			
			if slot.item.amount <= 0:
				slot.clear_slot()
				
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
			_update_cache(slot.item.data.item_id, slot.item.amount)
