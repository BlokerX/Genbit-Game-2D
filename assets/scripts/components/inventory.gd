# inventory.gd
extends Node
class_name Inventory

#region Inventory stats
## Rozmiar ekwipunku
@export var slots_amount: int = 4

## Maksymalna liczba slotów w pasku szybkiego dostępu (Hotbar)
@export var hotbar_limit: int = 9

## Używamy typowanej tablicy dla bezpieczeństwa i podpowiedzi w edytorze
@export var slots: Array[SlotData] = []

## Aktualnie wybrany indeks slotu
@export var current_slot_index : int = 0

## Specjalny slot przechowujący założony plecak
@export var backpack_slot: SlotData = SlotData.new()

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
	# ZABEZPIECZENIE: Odklejamy referencje startowych przedmiotów dodanych w Edytorze
	for i in range(slots.size()):
		if slots[i] != null:
			slots[i] = slots[i].duplicate(true)
			if not slots[i].is_empty():
				slots[i].item = slots[i].item.duplicate(true)
				slots[i].item.data = slots[i].item.data.duplicate(true)
		else:
			slots[i] = SlotData.new()
			
	_rebuild_cache()
	# Zmuszamy pamięć podręczną do odświeżania się za każdym razem, 
	# gdy w ekwipunku nastąpi jakakolwiek zmiana (np. przełożenie przedmiotu kursorem)!
	inventory_updated.connect(_rebuild_cache)


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

# =========================================================================
# ZAAWANSOWANY SYSTEM AMUNICJI (EJECT & LOAD)
# =========================================================================

## Szybka zmiana typu amunicji (np. ze Zwykłej na Przeciwpancerną)
func cycle_weapon_ammunition() -> void:
	var slot = get_current_slot()
	if slot.is_empty() or not slot.item.data is ItemDistanceWeapon: return
	var inst = slot.item
	var weapon_data = inst.data as ItemDistanceWeapon
	
	if not weapon_data.uses_ammunition: return
		
	# Szukamy wszystkich UNIKALNYCH rodzajów amunicji w plecaku pasujących do broni
	var available_ammo: Array[AmmunitionItem] = []
	for s in slots:
		if not s.is_empty() and s.item.data is AmmunitionItem:
			var ammo = s.item.data as AmmunitionItem
			if ammo.ammunition_type == weapon_data.accepted_ammunition_type:
				if not available_ammo.has(ammo): available_ammo.append(ammo)
					
	if available_ammo.is_empty():
		print("Brak pasującej amunicji do zmiany w ekwipunku.")
		return
		
	# Sprawdzamy co jest teraz załadowane / preferowane
	var current_pref_id = inst.custom_data.get("preferred_ammo_id", -1)
	if current_pref_id == -1 and inst.custom_data.get("ammo_data") != null:
		current_pref_id = inst.custom_data["ammo_data"].item_id
		
	# Wybieramy następny typ z listy
	var next_index = 0
	for i in range(available_ammo.size()):
		if available_ammo[i].item_id == current_pref_id:
			next_index = (i + 1) % available_ammo.size()
			break
			
	var next_ammo = available_ammo[next_index]
	inst.custom_data["preferred_ammo_id"] = next_ammo.item_id
	print(">>> Zmieniono preferencję na: ", next_ammo.item_name)
	
	# MAGIA: "WYPLUWANIE" OBECNYCH NABOI DO PLECAKA
	var current_ammo_count = inst.custom_data.get("ammo_count", 0)
	var current_ammo_data = inst.custom_data.get("ammo_data", null)
	
	if current_ammo_count > 0 and current_ammo_data != null:
		var old_instance = ItemInstance.new(current_ammo_data.duplicate(true), current_ammo_count)
		var leftovers = add_instance(old_instance)
		
		# Jeśli plecak jest w 100% pełny, wyrzuca pestki na ziemię!
		if leftovers != null: item_dropped.emit(leftovers, false)
			
		inst.custom_data["ammo_count"] = 0
		inst.custom_data["ammo_data"] = null
		
	# Od razu ładujemy nową amunicję (odpali to standardowy czas przeładowania na graczu)
	reload_current_weapon()

## Główna funkcja ładująca broń
func reload_current_weapon() -> bool:
	var slot = get_current_slot()
	if slot.is_empty() or not slot.item.data is ItemDistanceWeapon: return false
	
	var inst = slot.item
	var weapon_data = inst.data as ItemDistanceWeapon
	if not weapon_data.uses_ammunition: return false
	
	var current_ammo = inst.custom_data.get("ammo_count", 0)
	if current_ammo >= weapon_data.magazine_capacity: return false
	
	var preferred_id = inst.custom_data.get("preferred_ammo_id", -1)
	
	# FAZA 1: Próbujemy znaleźć dokładnie tę amunicję, której zażądał gracz (lub kontynuować załadowaną)
	var ammo_found = _try_load_ammo(inst, weapon_data, preferred_id)
	
	# FAZA 2: Jeśli nie mamy "Ulubionej", bierzemy JAKĄKOLWIEK inną, która pasuje do broni
	if ammo_found <= 0 and preferred_id != -1:
		ammo_found = _try_load_ammo(inst, weapon_data, -1)
		
	if ammo_found > 0:
		return true
		
	return false

# Funkcja pomocnicza ukrywająca brudną logikę zżerania stosów z plecaka
func _try_load_ammo(inst: ItemInstance, weapon_data: ItemDistanceWeapon, required_id: int) -> int:
	var current_ammo = inst.custom_data.get("ammo_count", 0)
	var ammo_needed = weapon_data.magazine_capacity - current_ammo
	var ammo_found = 0
	var ammo_reference: AmmunitionItem = inst.custom_data.get("ammo_data", null)
	
	for i in range(slots.size()):
		if not slots[i].is_empty() and slots[i].item.data is AmmunitionItem:
			var ammo_item = slots[i].item.data as AmmunitionItem
			
			if ammo_item.ammunition_type == weapon_data.accepted_ammunition_type:
				# Weryfikacja preferencji (jeśli wymagana)
				if required_id != -1 and ammo_item.item_id != required_id: continue
				# Zabezpieczenie przed ładowaniem dwóch rożnych typów do jednego magazynka!
				if ammo_reference != null and ammo_reference.item_id != ammo_item.item_id: continue
					
				ammo_reference = ammo_item 
				var taking = min(slots[i].item.amount, ammo_needed - ammo_found)
				slots[i].item.amount -= taking
				ammo_found += taking
				_update_cache(ammo_item.item_id, -taking)
				
				if slots[i].item.amount <= 0: slots[i].clear_slot()
				if ammo_found >= ammo_needed: break
					
	if ammo_found > 0:
		inst.custom_data["ammo_count"] = current_ammo + ammo_found
		inst.custom_data["ammo_data"] = ammo_reference
		inventory_updated.emit()
		print("Załadowano: ", ammo_found, " sztuk typu: ", ammo_reference.item_name)
		
	return ammo_found

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
		#ZABEZPIECZENIE PRZED WSPÓŁDZIELENIEM DANYCH PO WYRZUCENIU 1 SZTUKI
		var unique_data = slot.item.data.duplicate(true)
		instance_to_drop = ItemInstance.new(unique_data, 1)
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
			if not slot.is_empty() and slot.item.can_stack_with(instance_to_add):
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
	inventory_updated.emit()
	return instance_to_add

## Klasyczne tworzenie nowego przedmiotu z definicji (przydatne np. w rzemiośle)
func add_item(item: ItemData, amount_to_add: int = 1) -> int:
	if item == null or amount_to_add <= 0: return amount_to_add
	var remaining = amount_to_add
	
	# 1. Szukanie w stosach
	if item.item_is_stackable:
		# Pomocnicza instancja tylko do porównania
		var temp_instance = ItemInstance.new(item, 1) 
		for slot in slots:
			if not slot.is_empty() and slot.item.can_stack_with(temp_instance):
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


## Próba założenia lub wymiany plecaka w dedykowanym slocie
func equip_backpack(new_backpack_instance: ItemInstance) -> ItemInstance:
	var old_backpack = backpack_slot.item
	backpack_slot.item = new_backpack_instance
	
	_recalculate_slots_size()
	inventory_updated.emit()
	
	return old_backpack # Zwraca stary plecak (jeśli jakiś był założony), żeby wrócił do myszki/ekwipunku

func unequip_backpack() -> ItemInstance:
	var backpack = backpack_slot.item
	backpack_slot.clear_slot()
	
	_recalculate_slots_size()
	inventory_updated.emit()
	
	return backpack

## Przelicza rozmiar ekwipunku bazowego + bonus z plecaka
func _recalculate_slots_size() -> void:
	var base_slots = slots_amount
	var bonus_slots = 0
	
	if not backpack_slot.is_empty() and backpack_slot.item.data is BackpackItem:
		bonus_slots = (backpack_slot.item.data as BackpackItem).extra_slots_count
	
	var target_total_size = base_slots + bonus_slots
	
	if slots.size() != target_total_size:
		# --- NOWOŚĆ: Zabezpieczenie przed utratą itemów ---
		# Jeśli ekwipunek się zmniejsza, przed ucięciem tablicy wyrzucamy przedmioty na ziemię
		if target_total_size < slots.size():
			for i in range(target_total_size, slots.size()):
				if slots[i] != null and not slots[i].is_empty():
					# Zlecenie wyrzucenia przedmiotu pod nogi gracza
					item_dropped.emit(slots[i].item, false) 
		
		# Dopasowanie rozmiaru
		slots.resize(target_total_size)
		for i in range(target_total_size):
			if slots[i] == null:
				slots[i] = SlotData.new()
		
		# Ściągamy kursor zaznaczenia w dół, jeśli po zdjęciu plecaka znalazł się "w powietrzu"
		if current_slot_index >= slots.size():
			current_slot_index = max(0, slots.size() - 1)
		
		_rebuild_cache()


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
func select_item(index: int) -> void:
	# Ignoruje wciśnięcie klawisza przypisanego do slotu, którego fizycznie nie ma
	if index >= 0 and index < slots.size():
		current_slot_index = index
		inventory_updated.emit()

## Obsługa wybierania poprzedniego i następnego indeksu
func scroll_inventory(direction: int) -> void:
	# Scrollujemy tylko po widocznym hotbarze (bierzemy mniejszą wartość)
	var scrollable_amount = min(slots.size(), hotbar_limit)
	
	# Zabezpieczenie przed błędem dzielenia przez zero, jeśli slotów nie ma
	if scrollable_amount > 0:
		var new_index = wrapi(current_slot_index - direction, 0, scrollable_amount)
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
