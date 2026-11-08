# inventory.gd
extends Node
class_name Inventory

const RequirementPlanner = preload("res://assets/scripts/components/inventory_requirement_planner.gd")
const InventoryAmmunitionControllerType = preload(
	"res://assets/scripts/components/inventory_ammunition_controller.gd"
)
const InventoryPassiveControllerType = preload(
	"res://assets/scripts/components/inventory_passive_controller.gd"
)
const InventoryCapacityControllerType = preload(
	"res://assets/scripts/components/inventory_capacity_controller.gd"
)
const InventoryItemTransferControllerType = preload(
	"res://assets/scripts/components/inventory_item_transfer_controller.gd"
)

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
signal equipment_updated

# --- SYGNAŁY SRP DLA PASYWEK ---
signal held_passives_changed
signal equipment_passives_changed
signal inventory_passives_changed
#endregion

## PAMIĘĆ PODRĘCZNA DO CRAFTINGU (Format: { ID : Ilość })
var _item_count_cache: Dictionary = {}
var _tag_count_cache: Dictionary = {}
var _ammunition_controller: InventoryAmmunitionControllerType
var _passive_controller: InventoryPassiveControllerType
var _capacity_controller: InventoryCapacityControllerType
var _item_transfer_controller: InventoryItemTransferControllerType

## Słownik przechowujący założony sprzęt (Klucz to EquippableComponent.EquipSlot)
@export var equipment_slots: Dictionary = {}

## Constructor
func _init() -> void :
	slots.resize(slots_amount)
	for i in range(slots_amount):
		slots[i] = SlotData.new()

	# --- Inicjalizacja pustych slotów zbroi ---
	for slot_type in EquippableComponent.EquipSlot.values():
		if slot_type != EquippableComponent.EquipSlot.NONE:
			equipment_slots[slot_type] = SlotData.new()

	_ammunition_controller = InventoryAmmunitionControllerType.new()
	_ammunition_controller.initialize(self)
	_passive_controller = InventoryPassiveControllerType.new()
	_capacity_controller = InventoryCapacityControllerType.new()
	_item_transfer_controller = InventoryItemTransferControllerType.new()

## Zbudowanie cache na start gry
func _ready() -> void:
	slots_amount = maxi(0, slots_amount)
	if slots.size() < slots_amount:
		slots.resize(slots_amount)

	# ZABEZPIECZENIE: Odklejamy referencje startowych przedmiotów dodanych w Edytorze (przez create_unique_copy)
	for i in range(slots.size()):
		if slots[i] != null:
			slots[i] = slots[i].duplicate(true)
			if not slots[i].is_empty():
				slots[i].item = slots[i].item.duplicate(true)
				slots[i].item.data = slots[i].item.data.create_unique_copy()
		else:
			slots[i] = SlotData.new()

	if slots.is_empty():
		current_slot_index = 0
	else:
		current_slot_index = clampi(current_slot_index, 0, slots.size() - 1)

	_rebuild_cache()

	# Odświeżamy pamięć podręczną za każdym razem, gdy w ekwipunku nastąpi zmiana
	inventory_updated.connect(_rebuild_cache)

# ----------------------------------------------------
# --- SPRZĄTANIE PUSTYCH SLOTÓW ---
# ----------------------------------------------------

## Sprawdza ekwipunek i czyści sloty, w których skończyły się przedmioty
func clean_dead_items() -> void:
	var inventory_changed: bool = false

	# Sprzątanie głównych slotów
	for slot in slots:
		if slot.item != null and slot.item.state.has("amount"):
			if int(slot.item.state["amount"]) == 0 or int(slot.item.state["amount"]) < -1:
				slot.clear_slot()
				inventory_changed = true

	# Sprzątanie CAŁEJ ZBROI (w tym plecaka)
	for slot in equipment_slots.values():
		if slot.item != null and slot.item.state.has("amount"):
			if int(slot.item.state["amount"]) == 0 or int(slot.item.state["amount"]) < -1:
				slot.clear_slot()
				inventory_changed = true

	if inventory_changed:
		inventory_updated.emit()

## Zużywa część stosu w slocie; wywołujący powiadamia o zakończeniu całej operacji.
func consume_from_slot(slot_index: int, amount: int) -> int:
	if amount <= 0 or slot_index < 0 or slot_index >= slots.size():
		return 0
	var slot: SlotData = slots[slot_index]
	if slot == null or slot.is_empty():
		return 0
	var item: ItemInstance = slot.item
	var available_amount: int = item.state.get("amount", 1)
	var consumed_amount: int = mini(available_amount, amount)
	if consumed_amount <= 0:
		return 0
	var remaining_amount: int = available_amount - consumed_amount
	_update_cache(item.data.item_id, -consumed_amount)
	if remaining_amount == 0:
		slot.clear_slot()
	else:
		item.state["amount"] = remaining_amount
	return consumed_amount

## Wyrzuca wszystkie przedmioty gracza po śmierci.
func drop_all_items(_owner_entity: Node2D) -> void:
	var dropped_any: bool = false

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

## Zachowuje publiczny punkt wejścia używany przez broń i sterowanie gracza.
func cycle_weapon_ammunition() -> void:
	_ammunition_controller.cycle_weapon_ammunition()

## Zachowuje publiczny punkt wejścia używany przez broń i sterowanie gracza.
func reload_current_weapon() -> bool:
	return _ammunition_controller.reload_current_weapon()

# ----------------------------------------------------
# --- WYRZUCANIE I PODNOSZENIE ---
# ----------------------------------------------------

## Wyrzuca przedmiot z ekwipunku wywołując zdarzenie item_dropped z przesłaniem danych wyrzuconego przedmiotu
func drop_current_item(drop_all: bool = false) -> void:
	var slot: SlotData = get_current_slot()
	if slot == null or slot.is_empty():
		return

	var instance_to_drop: ItemInstance

	if drop_all:
		# Wyrzucamy całą instancję, wyciągniętą prosto ze slota!
		instance_to_drop = slot.item
		slot.clear_slot()
	else:
		# Wyrzucamy 1 sztukę z zachowaniem pełnego stanu (state) i unikalnych danych (create_split_copy)
		instance_to_drop = slot.item.create_split_copy(1)
		slot.item.consume_amount(1)
		clean_dead_items()

	inventory_updated.emit()
	item_dropped.emit(instance_to_drop, true)

## Przyjmuje istniejącą instancję z mapy (np. zużyty miecz lub połączone stosy łupu)
func add_instance(instance_to_add: ItemInstance) -> ItemInstance:
	return _item_transfer_controller.add_instance(self, instance_to_add)

## Klasyczne tworzenie nowego przedmiotu z definicji (przydatne np. w rzemiośle)
func add_item(item: ItemData, amount_to_add: int = 1) -> int:
	return _item_transfer_controller.add_item(self, item, amount_to_add)

## Próba założenia przedmiotu do dedykowanego slotu zbroi. Zwraca stary przedmiot (lub null)
func equip_item(new_equipment: ItemInstance, slot_type: EquippableComponent.EquipSlot) -> ItemInstance:
	var old_equipment: ItemInstance = equipment_slots[slot_type].item
	equipment_slots[slot_type].item = new_equipment

	_recalculate_slots_size() # Przeliczamy rozmiar ekwipunku, bo mógł to być plecak!
	equipment_updated.emit()
	inventory_updated.emit()
	return old_equipment

## Atomowo zużywa składniki i zastępuje wyposażenie bez przejściowego zmniejszania pojemności.
func try_replace_equipped_item_and_consume_requirements(
	slot_type: EquippableComponent.EquipSlot,
	expected_equipment: ItemInstance,
	replacement_equipment: ItemInstance,
	item_requirements: Dictionary,
	tag_requirements: Dictionary
) -> bool:
	if (
		not equipment_slots.has(slot_type)
		or expected_equipment == null
		or replacement_equipment == null
		or equipment_slots[slot_type].item != expected_equipment
		or _get_equippable_slot(replacement_equipment.data) != slot_type
	):
		return false

	var plan_result: Dictionary = RequirementPlanner.build_plan(slots, item_requirements, tag_requirements)
	if not plan_result.get("valid", false):
		return false

	_apply_requirement_plan(plan_result)
	equipment_slots[slot_type].item = replacement_equipment
	_recalculate_slots_size()
	equipment_updated.emit()
	inventory_updated.emit()
	return true

## Zwraca slot wyposażenia przypisany do przedmiotu lub NONE, jeśli nie jest zakładalny.
func _get_equippable_slot(item_data: ItemData) -> int:
	if item_data == null or item_data.components == null:
		return EquippableComponent.EquipSlot.NONE
	for component in item_data.components:
		if component is EquippableComponent:
			return component.equip_slot_type
	return EquippableComponent.EquipSlot.NONE

## Zdejmuje zbroję i zwraca ją (żeby wróciła do kursora lub ekwipunku)
func unequip_item(slot_type: EquippableComponent.EquipSlot) -> ItemInstance:
	var equipment: ItemInstance = equipment_slots[slot_type].item
	equipment_slots[slot_type].clear_slot()

	_recalculate_slots_size() # Przeliczamy, wyrzucając nadmiar z plecaka na ziemię!
	equipment_updated.emit()
	inventory_updated.emit()
	return equipment

# =========================================================
# --- SYSTEM PASYWEK (ZASADA POJEDYNCZEJ ODPOWIEDZIALNOŚCI) ---
# =========================================================

func get_held_passives() -> Array[Effect]:
	return _passive_controller.get_held_passives(self)

func get_equipment_passives() -> Array[Effect]:
	return _passive_controller.get_equipment_passives(self)

func get_inventory_passives() -> Array[Effect]:
	return _passive_controller.get_inventory_passives(self)

## Prosi obserwatorów o ponowne zastosowanie pasywek bez zmiany zawartości.
func refresh_passives() -> void:
	held_passives_changed.emit()
	equipment_passives_changed.emit()
	inventory_passives_changed.emit()

func _check_passive_deltas() -> void:
	var changes: Dictionary = _passive_controller.check_for_changes(self)
	if changes.has(InventoryPassiveControllerType.Change.HELD):
		held_passives_changed.emit()
	if changes.has(InventoryPassiveControllerType.Change.INVENTORY):
		inventory_passives_changed.emit()
	if changes.has(InventoryPassiveControllerType.Change.EQUIPMENT):
		equipment_passives_changed.emit()

## Przelicza rozmiar ekwipunku bazowego + bonus z plecaka
func _recalculate_slots_size() -> void:
	_capacity_controller.recalculate_slots_size(self)

# ----------------------------------------------------
# --- NAWIGACJA ---
# ----------------------------------------------------
func get_current_slot() -> SlotData :
	if slots != null and current_slot_index >= 0 and current_slot_index < slots.size():
		return slots[current_slot_index]
	return null

func get_current_item() -> ItemInstance :
	var slot: SlotData = get_current_slot()
	if slot != null and not slot.is_empty():
		return slot.item
	return null

## Zmienia aktualnie wybrany indeks aktualnego itemu
func select_item(index: int) -> void:
	if index >= 0 and index < slots.size():
		current_slot_index = index
		inventory_updated.emit()

## Obsługa wybierania poprzedniego i następnego indeksu
func scroll_inventory(direction: int) -> void:
	var scrollable_amount: int = mini(slots.size(), hotbar_limit)
	if scrollable_amount > 0:
		var new_index: int = wrapi(current_slot_index - direction, 0, scrollable_amount)
		select_item(new_index)

# ----------------------------------------------------
# --- BEZPĘTLOWY SYSTEM CRAFTINGU O(1) ---
# ----------------------------------------------------
func get_item_amount(item_id: StringName) -> int:
	return _item_count_cache.get(item_id, 0)

func has_items(item_id: StringName, required_amount: int) -> bool:
	return get_item_amount(item_id) >= required_amount

func consume_ingredients(item_id: StringName, required_amount: int) -> void:
	var remaining: int = required_amount

	for slot in slots:
		if not slot.is_empty() and slot.item.data.item_id == item_id:
			var slot_amount: int = slot.item.state.get("amount", 1)
			var taking: int = mini(slot_amount, remaining)

			slot.item.state["amount"] = slot_amount - taking
			remaining -= taking
			_update_cache(item_id, -taking)

			if slot.item.state["amount"] <= 0:
				slot.clear_slot()

			if remaining <= 0:
				break

	inventory_updated.emit()

## Sprawdza jednocześnie wymagania przedmiotów i tagów bez zmiany ekwipunku.
func has_requirements(item_requirements: Dictionary, tag_requirements: Dictionary) -> bool:
	return RequirementPlanner.build_plan(slots, item_requirements, tag_requirements).get("valid", false)

## Zużywa wymagania atomowo: nie zmienia ekwipunku, jeśli brakuje choć jednego składnika.
func try_consume_requirements(item_requirements: Dictionary, tag_requirements: Dictionary) -> bool:
	var plan_result: Dictionary = RequirementPlanner.build_plan(slots, item_requirements, tag_requirements)
	if not plan_result.get("valid", false):
		return false

	_apply_requirement_plan(plan_result)
	inventory_updated.emit()
	return true

## Stosuje wcześniej zwalidowany plan zużycia i aktualizuje cache bez emitowania sygnałów.
func _apply_requirement_plan(plan_result: Dictionary) -> void:
	var slot_consumption: Dictionary = plan_result["slot_consumption"]
	for slot_index: int in slot_consumption:
		var slot: SlotData = slots[slot_index]
		var item: ItemInstance = slot.item
		var consumed_amount: int = slot_consumption[slot_index]
		var remaining_amount: int = item.state.get("amount", 1) - consumed_amount
		_update_cache(item.data.item_id, -consumed_amount)
		if remaining_amount <= 0:
			slot.clear_slot()
		else:
			item.state["amount"] = remaining_amount

func _update_cache(item_id: StringName, diff: int) -> void:
	if not _item_count_cache.has(item_id):
		_item_count_cache[item_id] = 0
	_item_count_cache[item_id] += diff

## Funkcja odbudowująca cache po załadowaniu lub zmianie przedmiotów
func _rebuild_cache() -> void:
	_item_count_cache.clear()
	_tag_count_cache.clear()

	for slot in slots:
		if not slot.is_empty():
			var amt: int = slot.item.state.get("amount", 1)
			var data: ItemData = slot.item.data

			_update_cache(data.item_id, amt)

			for tag in data.tags:
				if not _tag_count_cache.has(tag):
					_tag_count_cache[tag] = 0
				_tag_count_cache[tag] += amt

	EventBus.game_event_occurred.emit("inventory_changed", {"inventory": self})
	_check_passive_deltas()

# --- NARZĘDZIA DLA TAGÓW ---
func get_tag_amount(tag: StringName) -> int:
	return _tag_count_cache.get(tag, 0)

func has_items_by_tag(tag: StringName, required_amount: int) -> bool:
	return get_tag_amount(tag) >= required_amount

func consume_by_tag(tag: StringName, required_amount: int) -> void:
	var remaining: int = required_amount

	for slot in slots:
		if not slot.is_empty() and slot.item.data.has_tag(tag):
			var slot_amount: int = slot.item.state.get("amount", 1)
			var taking: int = mini(slot_amount, remaining)

			slot.item.state["amount"] = slot_amount - taking
			remaining -= taking

			if slot.item.state["amount"] <= 0:
				slot.clear_slot()

			if remaining <= 0:
				break

	inventory_updated.emit()
