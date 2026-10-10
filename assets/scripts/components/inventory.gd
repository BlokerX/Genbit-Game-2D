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

#endregion


#region Signals

## Sygnał, który powiadomi UI o zmianie
signal inventory_updated

signal item_dropped(dropped_instance: ItemInstance, is_thrown: bool)

# W sekcji sygnałów dodaj:
signal equipment_updated

# --- SYGNAŁY SRP DLA PASYWEK ---
signal held_passives_changed
signal equipment_passives_changed
signal inventory_passives_changed

#endregion

## PAMIĘĆ PODRĘCZNA DO CRAFTINGU (Format: { ID : Ilość })
var _item_count_cache: Dictionary = {}
var _tag_count_cache: Dictionary = {}

# --- PAMIĘĆ SYGNATUR PASYWEK ---
var _last_held_sig: String = ""
var _last_equip_sig: String = ""
var _last_inv_sig: String = ""

## Słownik przechowujący założony sprzęt (Klucz to EquippableComponent.EquipSlot)
@export var equipment_slots: Dictionary = {}

## Constructor
func _init() -> void :
	# Wszystkie miejsca będą na start miały wartość 'null' (pusty slot).
	slots.resize(slots_amount)
	for i in range(slots_amount):
		slots[i] = SlotData.new() # Przygotowanie pustych pojemników
	
	# --- Inicjalizacja pustych slotów zbroi ---
	# Generujemy szufladkę dla każdego typu pancerza zdefiniowanego w komponencie
	for slot_type in EquippableComponent.EquipSlot.values():
		if slot_type != EquippableComponent.EquipSlot.NONE:
			equipment_slots[slot_type] = SlotData.new()

## Zbudowanie cache na start gry
func _ready() -> void:
	slots_amount = maxi(0, slots_amount)
	if slots.size() < slots_amount:
		slots.resize(slots_amount)

	# ZABEZPIECZENIE: Odklejamy referencje startowych przedmiotów dodanych w Edytorze
	for i in range(slots.size()):
		if slots[i] != null:
			slots[i] = slots[i].duplicate(true)
			if not slots[i].is_empty():
				slots[i].item = slots[i].item.duplicate(true)
				slots[i].item.data = slots[i].item.data.duplicate(true)
		else:
			slots[i] = SlotData.new()
			
	if slots.is_empty():
		current_slot_index = 0
	else:
		current_slot_index = clampi(current_slot_index, 0, slots.size() - 1)

	_rebuild_cache()
	# Zmuszamy pamięć podręczną do odświeżania się za każdym razem, 
	# gdy w ekwipunku nastąpi jakakolwiek zmiana (np. przełożenie przedmiotu kursorem)!
	inventory_updated.connect(_rebuild_cache)

# ----------------------------------------------------
# --- SPRZĄTANIE PUSTYCH SLOTÓW ---
# ----------------------------------------------------
## Sprawdza ekwipunek i czyści sloty, w których skończyły się przedmioty
func clean_dead_items() -> void:
	var inventory_changed = false
	
	# Sprzątanie głównych slotów
	for slot in slots:
		if slot.item != null and slot.item.state.has("amount"):
			if slot.item.state["amount"] <= 0:
				slot.clear_slot()
				inventory_changed = true
				
	# Sprzątanie CAŁEJ ZBROI (w tym plecaka)
	for slot in equipment_slots.values():
		if slot.item != null and slot.item.state.has("amount"):
			if slot.item.state["amount"] <= 0:
				slot.clear_slot()
				inventory_changed = true

	if inventory_changed:
		inventory_updated.emit()

## Wyrzuca wszystkie przedmioty gracza po śmierci.
func drop_all_items(_owner_entity: Node2D) -> void:
	var dropped_any = false

	for slot in slots:
		if not slot.is_empty():
			item_dropped.emit(slot.item, false)
			slot.clear_slot()
			dropped_any = true

	for slot in equipment_slots.values():
		if not slot.is_empty():
			item_dropped.emit(slot.item, false)
			slot.clear_slot()
			dropped_any = true

	if dropped_any:
		_recalculate_slots_size()
		equipment_updated.emit()
		inventory_updated.emit()

# =========================================================================
# ZAAWANSOWANY SYSTEM AMUNICJI (EJECT & LOAD)
# =========================================================================

# --- NOWOŚĆ: Funkcja pomocnicza znajdująca komponent dystansowy w broni ---
func _get_ranged_comp(item: ItemInstance) -> RangedWeaponComponent:
	if item == null or item.data == null or item.data.components == null:
		return null
	for comp in item.data.components:
		if comp is RangedWeaponComponent:
			return comp
	return null

## Szybka zmiana typu amunicji (np. ze Zwykłej na Przeciwpancerną)
func cycle_weapon_ammunition() -> void:
	var slot = get_current_slot()
	if slot.is_empty(): return
		
	# UŻYWAMY FUNKCJI POMOCNICZEJ ZAMIAST PYTAĆ O KLASĘ 'ItemDistanceWeapon'
	var weapon_comp = _get_ranged_comp(slot.item)
	if not weapon_comp or not weapon_comp.uses_ammunition: return
		
	var available_ammo: Array[ItemData] = []
	for s in slots:
		if not s.is_empty():
			# SZUKAMY KLOCKA 'AmmunitionComponent'
			for comp in s.item.data.components:
				if comp is AmmunitionComponent and comp.ammunition_type == weapon_comp.accepted_ammunition_type:
					if not available_ammo.has(s.item.data):
						available_ammo.append(s.item.data)
					break
					
	if available_ammo.is_empty():
		print("Brak pasującej amunicji do zmiany w ekwipunku.")
		return
		
	var inst = slot.item
	var current_pref_id = inst.state.get("preferred_ammo_id", &"")
	
	# --- ZMIANA: Szukamy w bazie po ID ---
	var current_ammo_id = inst.state.get("ammo_id", &"")
	var current_ammo_data = ItemDatabase.get_item(current_ammo_id) if current_ammo_id != &"" else null
	
	if (current_pref_id == null or str(current_pref_id) == "") and current_ammo_data != null:
		current_pref_id = current_ammo_data.item_id
		
	var next_index = 0
	for i in range(available_ammo.size()):
		if available_ammo[i].item_id == current_pref_id:
			next_index = (i + 1) % available_ammo.size()
			break
			
	var next_ammo_data = available_ammo[next_index]
	inst.state["preferred_ammo_id"] = next_ammo_data.item_id
	print(">>> Zmieniono preferencję na: ", next_ammo_data.item_name)
	
	var current_ammo_count = inst.state.get("ammo_count", 0)
	# Zmienna current_ammo_data została już zadeklarowana i pobrana bezpiecznie wyżej!
	
	if current_ammo_count > 0 and current_ammo_data != null:
		var old_instance = ItemInstance.new(current_ammo_data.duplicate(true), current_ammo_count)
		var leftovers = add_instance(old_instance)
		if leftovers != null:
			item_dropped.emit(leftovers, false)
			
	inst.state["ammo_count"] = 0
	inst.state["ammo_id"] = &"" # <--- ZMIANA z ammo_data na ammo_id
	reload_current_weapon()

## Główna funkcja ładująca broń
func reload_current_weapon() -> bool:
	var slot = get_current_slot()
	if slot.is_empty(): return false
		
	var weapon_comp = _get_ranged_comp(slot.item)
	if not weapon_comp or not weapon_comp.uses_ammunition: return false
		
	var inst = slot.item
	var current_ammo = inst.state.get("ammo_count", 0)
	if current_ammo >= weapon_comp.magazine_capacity: return false
		
	var preferred_id = inst.state.get("preferred_ammo_id", &"")
	
	var ammo_found = _try_load_ammo(inst, weapon_comp, preferred_id)
	
	# Jeśli ulubiona amunicja się skończyła, próbujemy załadować cokolwiek, co pasuje (stąd puste &"")
	if ammo_found <= 0 and str(preferred_id) != "":
		ammo_found = _try_load_ammo(inst, weapon_comp, &"")
		
	return ammo_found > 0

func _try_load_ammo(inst: ItemInstance, weapon_comp: RangedWeaponComponent, required_id: Variant) -> int:
	var current_ammo = inst.state.get("ammo_count", 0)
	var ammo_needed = weapon_comp.magazine_capacity - current_ammo
	var ammo_found = 0
	
	# --- ZMIANA: Odczyt po ID z bazy ---
	var current_ammo_id = inst.state.get("ammo_id", &"")
	var ammo_reference: ItemData = ItemDatabase.get_item(current_ammo_id) if current_ammo_id != &"" else null
	
	for i in range(slots.size()):
		if not slots[i].is_empty():
			var ammo_comp: AmmunitionComponent = null
			for comp in slots[i].item.data.components:
				if comp is AmmunitionComponent:
					ammo_comp = comp
					break
					
			if ammo_comp and ammo_comp.ammunition_type == weapon_comp.accepted_ammunition_type:
				var req_str = str(required_id)
				if req_str != "" and req_str != "-1" and str(slots[i].item.data.item_id) != req_str:
					continue
					
				if ammo_reference != null and ammo_reference.item_id != slots[i].item.data.item_id:
					continue
					
				ammo_reference = slots[i].item.data
				var slot_amount = slots[i].item.state.get("amount", 1)
				var taking = min(slot_amount, ammo_needed - ammo_found)
				
				slots[i].item.state["amount"] = slot_amount - taking
				ammo_found += taking
				_update_cache(ammo_reference.item_id, -taking)
				
				if slots[i].item.state["amount"] <= 0:
					slots[i].clear_slot()
					
				if ammo_found >= ammo_needed: break
					
	if ammo_found > 0:
		inst.state["ammo_count"] = current_ammo + ammo_found
		inst.state["ammo_id"] = ammo_reference.item_id # <--- ZMIANA
		inventory_updated.emit()
		print("Załadowano: ", ammo_found, " sztuk typu: ", ammo_reference.item_name)
		
	return ammo_found

# ----------------------------------------------------
# --- WYRZUCANIE I PODNOSZENIE ---
# ----------------------------------------------------

## Wyrzuca przedmiot z ekwipunku wywołując zdarzenie item_dropped z przesłaniem danych wyrzuconego przedmiotu
func drop_current_item(drop_all: bool = false) -> void:
	var slot = get_current_slot()
	if slot.is_empty():
		return
		
	var instance_to_drop: ItemInstance
	
	if drop_all:
		# Wyrzucamy całą instancję, wyciągniętą prosto ze slota!
		instance_to_drop = slot.item
		slot.clear_slot()
	else:
		# Wyrzucamy 1 sztukę: Klonujemy szablon (ItemData)
		var unique_data = slot.item.data.duplicate(true)
		instance_to_drop = ItemInstance.new(unique_data, 1)
		
		# --- OSTATECZNA ZMIANA ECS: Kopiujemy CAŁĄ DUSZĘ (słownik state) ---
		# Dzięki temu wyrzucona sztuka pamięta nie tylko "durability", ale też 
		# załadowaną amunicję, baterię, klątwy i wszystko inne, co kiedyś dodasz.
		instance_to_drop.state = slot.item.state.duplicate(true)
		instance_to_drop.state["amount"] = 1 # Wymuszamy, by wyrzucona paczka miała tylko 1 sztukę
			
		# UŻYWAMY NOWEJ FUNKCJI z ItemInstance, żeby zjeść 1 sztukę z ekwipunku
		slot.item.consume_amount(1)
		clean_dead_items() # Wywołujemy naszego nowego śmieciarza!
		
	inventory_updated.emit()
	# Informujemy świat, wysyłając CAŁĄ INSTANCJĘ do wyrzucenia na ziemię
	item_dropped.emit(instance_to_drop, true)

## Przyjmuje istniejącą instancję z mapy (np. zużyty miecz lub połączone stosy łupu)
func add_instance(instance_to_add: ItemInstance) -> ItemInstance:
	# 1. Sprawdzamy stan poprzez bezpieczny odczyt słownika 'state'
	var add_amount = instance_to_add.state.get("amount", 1) if instance_to_add != null else 0
	if instance_to_add == null or add_amount <= 0: 
		return null
		
	# 2. ZAMIAST PYTAĆ O WŁAŚCIWOŚĆ, SZUKAMY KLOCKA 'StackComponent'
	var is_stackable = false
	var max_stack = 1
	if instance_to_add.data.components != null:
		for comp in instance_to_add.data.components:
			if comp is StackComponent:
				is_stackable = true
				max_stack = comp.max_stack # Zapisujemy max_stack z komponentu
				break
				
	# 3. Jeśli przedmiot ma klocek do stackowania, szukamy dla niego miejsca w istniejących stosach
	if is_stackable:
		for slot in slots:
			if not slot.is_empty() and slot.item.can_stack_with(instance_to_add):
				var slot_amount = slot.item.state.get("amount", 1)
				var available_space = max_stack - slot_amount
				
				if available_space > 0:
					var adding = min(instance_to_add.state.get("amount", 1), available_space)
					
					# Aktualizujemy stany obu przedmiotów
					slot.item.state["amount"] = slot_amount + adding
					instance_to_add.state["amount"] = instance_to_add.state.get("amount", 1) - adding
					
					# Rejestrujemy to w pamięci craftingu
					_update_cache(instance_to_add.data.item_id, adding)
					
					if instance_to_add.state["amount"] <= 0:
						inventory_updated.emit()
						return null # Całość się zmieściła, kończymy pracę
						
	# 4. Jeśli przedmiot nie jest stackowalny, lub zostały nam resztki:
	# Próbujemy wrzucić do slotu trzymanego aktualnie w dłoni (jeśli jest pusty)
	var current_slot = get_current_slot()
	if current_slot != null and current_slot.is_empty():
		current_slot.item = instance_to_add
		_update_cache(instance_to_add.data.item_id, instance_to_add.state.get("amount", 1))
		inventory_updated.emit()
		return null
		
	# 5. Szukamy jakiegokolwiek innego pustego slota od lewej
	for slot in slots:
		if slot.is_empty():
			slot.item = instance_to_add 
			_update_cache(instance_to_add.data.item_id, instance_to_add.state.get("amount", 1))
			inventory_updated.emit()
			return null
			
	# 6. Całkowity brak miejsca - zwracamy instancję z powrotem na ziemię
	inventory_updated.emit()
	return instance_to_add

## Klasyczne tworzenie nowego przedmiotu z definicji (przydatne np. w rzemiośle)
func add_item(item: ItemData, amount_to_add: int = 1) -> int:
	if item == null or amount_to_add <= 0:
		return amount_to_add
		
	var remaining = amount_to_add
	
	# SZUKAMY KLOCKA 'StackComponent' ZAMIAST CZYTAĆ ZMIENNE
	var is_stackable = false
	var max_item_stack = 1
	if item.components != null:
		for comp in item.components:
			if comp is StackComponent:
				is_stackable = true
				max_item_stack = comp.max_stack
				break
				
	# 1. Szukanie w stosach
	if is_stackable:
		var temp_instance = ItemInstance.new(item, 1) 
		for slot in slots:
			if not slot.is_empty() and slot.item.can_stack_with(temp_instance):
				var slot_amount = slot.item.state.get("amount", 1)
				var available_space = max_item_stack - slot_amount
				
				if available_space > 0:
					var adding = min(remaining, available_space)
					slot.item.state["amount"] = slot_amount + adding
					remaining -= adding
					
					_update_cache(item.item_id, adding)
					
					if remaining == 0:
						inventory_updated.emit()
						return 0
						
	# 2. Szukanie pustych w wybranej ręce
	var current_slot = get_current_slot()
	if current_slot != null and current_slot.is_empty():
		var adding = min(remaining, max_item_stack) if is_stackable else 1
		current_slot.set_item_data(item, adding)
		remaining -= adding
		_update_cache(item.item_id, adding)
		if remaining == 0:
			inventory_updated.emit()
			return 0
			
	# 3. Szukanie dowolnego pustego od lewej
	for slot in slots:
		if slot.is_empty():
			var adding = min(remaining, max_item_stack) if is_stackable else 1
			slot.set_item_data(item, adding)
			remaining -= adding
			_update_cache(item.item_id, adding)
			if remaining == 0:
				inventory_updated.emit()
				return 0
				
	# 4. Jeśli zabrakło miejsca w całym ekwipunku, zwracamy to, co nam zostało w dłoni
	inventory_updated.emit()
	return remaining

## Próba założenia przedmiotu do dedykowanego slotu zbroi. Zwraca stary przedmiot (lub null)
func equip_item(new_equipment: ItemInstance, slot_type: EquippableComponent.EquipSlot) -> ItemInstance:
	var old_equipment = equipment_slots[slot_type].item
	equipment_slots[slot_type].item = new_equipment
	
	_recalculate_slots_size() # <--- Przeliczamy rozmiar ekwipunku, bo mógł to być plecak!
	equipment_updated.emit()
	inventory_updated.emit()
	return old_equipment

## Zdejmuje zbroję i zwraca ją (żeby wróciła do kursora lub ekwipunku)
func unequip_item(slot_type: EquippableComponent.EquipSlot) -> ItemInstance:
	var equipment = equipment_slots[slot_type].item
	equipment_slots[slot_type].clear_slot()
	
	_recalculate_slots_size() # <--- Przeliczamy, wyrzucając nadmiar z plecaka na ziemię!
	equipment_updated.emit()
	inventory_updated.emit()
	return equipment

# =========================================================
# --- SYSTEM PASYWEK (ZASADA POJEDYNCZEJ ODPOWIEDZIALNOŚCI) ---
# =========================================================

func get_held_passives() -> Array[Effect]:
	var active_effects: Array[Effect] = []
	var held_slot = get_current_slot()
	if held_slot != null and not held_slot.is_empty() and held_slot.item.data.components != null:
		for comp in held_slot.item.data.components:
			if comp is PassiveItemComponent and comp.requirement == PassiveItemComponent.PassiveRequirement.HELD:
				var count = held_slot.item.state.get("amount", 1) if comp.stack_effects_with_amount else 1
				for i in range(count): active_effects.append_array(comp.passive_buffs)
	return active_effects

func get_equipment_passives() -> Array[Effect]:
	var active_effects: Array[Effect] = []
	# Zbroja (w tym plecak, bo plecak to teraz po prostu zbroja na slocie BACKPACK!)
	for slot_type in equipment_slots.keys():
		var slot_data = equipment_slots[slot_type]
		if not slot_data.is_empty() and slot_data.item.data.components != null:
			for comp in slot_data.item.data.components:
				if comp is EquippableComponent and comp.equip_slot_type == slot_type:
					active_effects.append_array(comp.passive_buffs)
	return active_effects

func get_inventory_passives() -> Array[Effect]:
	var active_effects: Array[Effect] = []
	for slot_data in slots:
		if not slot_data.is_empty() and slot_data.item.data.components != null:
			for comp in slot_data.item.data.components:
				if comp is PassiveItemComponent and comp.requirement == PassiveItemComponent.PassiveRequirement.INVENTORY:
					var count = slot_data.item.state.get("amount", 1) if comp.stack_effects_with_amount else 1
					for i in range(count): active_effects.append_array(comp.passive_buffs)
	return active_effects

# --- GENERATORY SYGNATUR (Wykrywanie zmian w czasie rzeczywistym) ---
func _check_passive_deltas() -> void:
	var held_sig = ""
	var held = get_current_item()
	if held != null: held_sig = str(held.data.item_id) + ":" + str(held.state.get("amount", 1))
	if held_sig != _last_held_sig:
		_last_held_sig = held_sig
		held_passives_changed.emit()

	var inv_sig = ""
	for slot in slots:
		if not slot.is_empty() and slot.item.data.components != null:
			for comp in slot.item.data.components:
				if comp is PassiveItemComponent and comp.requirement == PassiveItemComponent.PassiveRequirement.INVENTORY:
					inv_sig += str(slot.item.data.item_id) + ":" + str(slot.item.state.get("amount", 1)) + "|"
	if inv_sig != _last_inv_sig:
		_last_inv_sig = inv_sig
		inventory_passives_changed.emit()

	var equip_sig = ""
	# Cała zbroja i plecak w jednej, zgrabnej pętli:
	for slot_type in equipment_slots.keys():
		var slot_data = equipment_slots[slot_type]
		if not slot_data.is_empty():
			equip_sig += str(slot_type) + ":" + str(slot_data.item.data.item_id) + "|"
	if equip_sig != _last_equip_sig:
		_last_equip_sig = equip_sig
		equipment_passives_changed.emit()

## Przelicza rozmiar ekwipunku bazowego + bonus z plecaka
func _recalculate_slots_size() -> void:
	var base_slots = maxi(0, slots_amount)
	var bonus_slots = 0
	
	# Zabezpieczenie przed błędem, jeśli w equipment_slots nie ma jeszcze klucza BACKPACK
	if equipment_slots.has(EquippableComponent.EquipSlot.BACKPACK):
		var bp_slot = equipment_slots[EquippableComponent.EquipSlot.BACKPACK]
		if not bp_slot.is_empty() and bp_slot.item.data.components != null:
			for comp in bp_slot.item.data.components:
				if comp is BackpackComponent:
					bonus_slots = comp.extra_slots_count
					break
				
	var target_total_size = base_slots + bonus_slots
	
	if slots.size() != target_total_size:
		if target_total_size < slots.size():
			for i in range(target_total_size, slots.size()):
				if slots[i] != null and not slots[i].is_empty():
					item_dropped.emit(slots[i].item, false) 
					
		slots.resize(target_total_size)
		for i in range(target_total_size):
			if slots[i] == null:
				slots[i] = SlotData.new()
				
		if current_slot_index >= slots.size():
			current_slot_index = max(0, slots.size() - 1)
			
	_rebuild_cache()

# ----------------------------------------------------
# --- NAWIGACJA ---
# ----------------------------------------------------

func get_current_slot() -> SlotData :
	if slots != null and current_slot_index >= 0 and current_slot_index < slots.size():
		return slots[current_slot_index]
	else: return null

func get_current_item() -> ItemInstance :
	var slot = get_current_slot()
	if slot != null and not slot.is_empty():
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

# ZMIANA: item_id to teraz StringName (np. &"wood"), a nie int!
func get_item_amount(item_id: StringName) -> int:
	return _item_count_cache.get(item_id, 0)

func has_items(item_id: StringName, required_amount: int) -> bool:
	return get_item_amount(item_id) >= required_amount

func consume_ingredients(item_id: StringName, required_amount: int) -> void:
	var remaining = required_amount
	for slot in slots:
		if not slot.is_empty() and slot.item.data.item_id == item_id:
			# ZMIANA: Pobieramy ze słownika zamiast ze zmiennej
			var slot_amount = slot.item.state.get("amount", 1)
			var taking = min(slot_amount, remaining)
			
			slot.item.state["amount"] = slot_amount - taking
			remaining -= taking
			_update_cache(item_id, -taking)
			
			if slot.item.state["amount"] <= 0:
				slot.clear_slot()
				
			if remaining <= 0: break
			
	inventory_updated.emit()

func _update_cache(item_id: StringName, diff: int) -> void:
	if not _item_count_cache.has(item_id):
		_item_count_cache[item_id] = 0
	_item_count_cache[item_id] += diff

## Funkcja odbudowująca cache po ręcznym załadowaniu przedmiotów
func _rebuild_cache() -> void:
	_item_count_cache.clear()
	_tag_count_cache.clear()
	
	for slot in slots:
		if not slot.is_empty():
			var amt = slot.item.state.get("amount", 1)
			var data = slot.item.data
			
			# Liczymy po ID
			_update_cache(data.item_id, amt)
			
			# Liczymy po Tagach (Jeśli przedmiot ma tag "wood" i "flammable", doda je oba)
			for tag in data.tags:
				if not _tag_count_cache.has(tag):
					_tag_count_cache[tag] = 0
				_tag_count_cache[tag] += amt
	
	# --- JEDNA LINIJKA, KTÓRA ZASILA WSZYSTKIE QUESTY ZBIERACKIE ---
	# Podajemy cały ekwipunek, niech Questy same sobie w nim pogrzebią i sprawdzą co masz!
	EventBus.game_event_occurred.emit("inventory_changed", {"inventory": self})
	
	# --- SPRAWDZENIE ZMIAN W PASYWKACH ---
	_check_passive_deltas()

# --- NARZĘDZIA DLA TAGÓW ---
func get_tag_amount(tag: StringName) -> int:
	return _tag_count_cache.get(tag, 0)

func has_items_by_tag(tag: StringName, required_amount: int) -> bool:
	return get_tag_amount(tag) >= required_amount

func consume_by_tag(tag: StringName, required_amount: int) -> void:
	var remaining = required_amount
	for slot in slots:
		if not slot.is_empty() and slot.item.data.has_tag(tag):
			var slot_amount = slot.item.state.get("amount", 1)
			var taking = min(slot_amount, remaining)
			
			slot.item.state["amount"] = slot_amount - taking
			remaining -= taking
			
			if slot.item.state["amount"] <= 0:
				slot.clear_slot()
				
			if remaining <= 0: break
			
	inventory_updated.emit() # Automatycznie odpali _rebuild_cache() i zaktualizuje UI!
