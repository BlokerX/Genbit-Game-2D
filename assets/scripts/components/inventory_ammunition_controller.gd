extends RefCounted
class_name InventoryAmmunitionController

var _inventory: Inventory

func initialize(inventory: Inventory) -> void:
	_inventory = inventory

func cycle_weapon_ammunition() -> void:
	var slot := _inventory.get_current_slot()
	if slot == null or slot.is_empty():
		return

	var weapon_component := _get_ranged_component(slot.item)
	if weapon_component == null or not weapon_component.uses_ammunition:
		return

	var available_ammunition: Array[ItemData] = []
	for inventory_slot in _inventory.slots:
		if inventory_slot.is_empty():
			continue

		for component in inventory_slot.item.data.components:
			if (
				component is AmmunitionComponent
				and component.ammunition_type == weapon_component.accepted_ammunition_type
			):
				if not available_ammunition.has(inventory_slot.item.data):
					available_ammunition.append(inventory_slot.item.data)
				break

	if available_ammunition.is_empty():
		print("Brak pasującej amunicji do zmiany w ekwipunku.")
		return

	var weapon_instance := slot.item
	var preferred_ammo_id = weapon_instance.state.get("preferred_ammo_id", &"")
	var current_ammo_id = weapon_instance.state.get("ammo_id", &"")
	var current_ammo_data: ItemData = (
		ItemDatabase.get_item(current_ammo_id) if current_ammo_id != &"" else null
	)

	if (preferred_ammo_id == null or str(preferred_ammo_id) == "") and current_ammo_data != null:
		preferred_ammo_id = current_ammo_data.item_id

	var next_index := 0
	for index in range(available_ammunition.size()):
		if available_ammunition[index].item_id == preferred_ammo_id:
			next_index = (index + 1) % available_ammunition.size()
			break

	var next_ammo_data := available_ammunition[next_index]
	weapon_instance.state["preferred_ammo_id"] = next_ammo_data.item_id
	print(">>> Zmieniono preferencję na: ", next_ammo_data.item_name)

	var current_ammo_count = weapon_instance.state.get("ammo_count", 0)
	if current_ammo_count > 0 and current_ammo_data != null:
		var old_ammo = ItemInstance.new(current_ammo_data.duplicate(true), current_ammo_count)
		var leftovers = _inventory.add_instance(old_ammo)
		if leftovers != null:
			_inventory.item_dropped.emit(leftovers, false)

	weapon_instance.state["ammo_count"] = 0
	weapon_instance.state["ammo_id"] = &""
	reload_current_weapon()

func reload_current_weapon() -> bool:
	var slot := _inventory.get_current_slot()
	if slot == null or slot.is_empty():
		return false

	var weapon_component := _get_ranged_component(slot.item)
	if weapon_component == null or not weapon_component.uses_ammunition:
		return false

	var weapon_instance := slot.item
	var current_ammo_count = weapon_instance.state.get("ammo_count", 0)
	if current_ammo_count >= weapon_component.magazine_capacity:
		return false

	var preferred_ammo_id = weapon_instance.state.get("preferred_ammo_id", &"")
	var ammo_found := _try_load_ammo(weapon_instance, weapon_component, preferred_ammo_id)

	if ammo_found <= 0 and str(preferred_ammo_id) != "":
		ammo_found = _try_load_ammo(weapon_instance, weapon_component, &"")

	return ammo_found > 0

func _try_load_ammo(
	weapon_instance: ItemInstance,
	weapon_component: RangedWeaponComponent,
	required_id: Variant
) -> int:
	var current_ammo_count = weapon_instance.state.get("ammo_count", 0)
	var ammo_needed = weapon_component.magazine_capacity - current_ammo_count
	var ammo_found := 0

	var current_ammo_id = weapon_instance.state.get("ammo_id", &"")
	var ammo_reference: ItemData = (
		ItemDatabase.get_item(current_ammo_id) if current_ammo_id != &"" else null
	)

	for index in range(_inventory.slots.size()):
		var slot: SlotData = _inventory.slots[index]
		if slot.is_empty():
			continue

		var ammunition_component: AmmunitionComponent = null
		for component in slot.item.data.components:
			if component is AmmunitionComponent:
				ammunition_component = component
				break

		if (
			ammunition_component == null
			or ammunition_component.ammunition_type != weapon_component.accepted_ammunition_type
		):
			continue

		var required_id_string := str(required_id)
		if (
			required_id_string != ""
			and required_id_string != "-1"
			and str(slot.item.data.item_id) != required_id_string
		):
			continue

		if ammo_reference != null and ammo_reference.item_id != slot.item.data.item_id:
			continue

		ammo_reference = slot.item.data
		var slot_amount = slot.item.state.get("amount", 1)
		var taking = min(slot_amount, ammo_needed - ammo_found)
		slot.item.state["amount"] = slot_amount - taking
		ammo_found += taking
		_inventory._update_cache(ammo_reference.item_id, -taking)

		if slot.item.state["amount"] <= 0:
			slot.clear_slot()

		if ammo_found >= ammo_needed:
			break

	if ammo_found > 0:
		weapon_instance.state["ammo_count"] = current_ammo_count + ammo_found
		weapon_instance.state["ammo_id"] = ammo_reference.item_id
		_inventory.inventory_updated.emit()
		print("Załadowano: ", ammo_found, " sztuk typu: ", ammo_reference.item_name)

	return ammo_found

func _get_ranged_component(item: ItemInstance) -> RangedWeaponComponent:
	if item == null or item.data == null or item.data.components == null:
		return null

	for component in item.data.components:
		if component is RangedWeaponComponent:
			return component
	return null
