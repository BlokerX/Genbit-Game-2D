class_name InventoryCapacityController
extends RefCounted

## Przelicza pojemność ekwipunku na podstawie slotów bazowych i założonego plecaka.
func recalculate_slots_size(inventory: Inventory) -> void:
	var base_slots := maxi(0, inventory.slots_amount)
	var bonus_slots := _get_backpack_slot_bonus(inventory)
	var target_total_size := base_slots + bonus_slots

	if inventory.slots.size() != target_total_size:
		if target_total_size < inventory.slots.size():
			_drop_items_from_removed_slots(inventory, target_total_size)

		inventory.slots.resize(target_total_size)
		_fill_empty_slots(inventory)
		_clamp_current_slot_index(inventory)

	inventory._rebuild_cache()

## Zwraca liczbę dodatkowych slotów przyznanych przez założony plecak.
func _get_backpack_slot_bonus(inventory: Inventory) -> int:
	# Zabezpieczenie przed błędem, jeśli w equipment_slots nie ma jeszcze klucza BACKPACK
	if not inventory.equipment_slots.has(EquippableComponent.EquipSlot.BACKPACK):
		return 0

	var backpack_slot: SlotData = inventory.equipment_slots[
		EquippableComponent.EquipSlot.BACKPACK
	]
	if backpack_slot.is_empty() or backpack_slot.item.data.components == null:
		return 0

	for component in backpack_slot.item.data.components:
		if component is BackpackComponent:
			return component.extra_slots_count

	return 0

## Wyrzuca przedmioty z miejsc, które znikną po zmniejszeniu pojemności.
func _drop_items_from_removed_slots(inventory: Inventory, target_total_size: int) -> void:
	for slot_index in range(target_total_size, inventory.slots.size()):
		var slot: SlotData = inventory.slots[slot_index]
		if slot != null and not slot.is_empty():
			inventory.item_dropped.emit(slot.item, false)

## Odtwarza puste obiekty slotów po zmianie rozmiaru tablicy.
func _fill_empty_slots(inventory: Inventory) -> void:
	for slot_index in range(inventory.slots.size()):
		if inventory.slots[slot_index] == null:
			inventory.slots[slot_index] = SlotData.new()

## Utrzymuje wybrany indeks w granicach aktualnej pojemności.
func _clamp_current_slot_index(inventory: Inventory) -> void:
	if inventory.current_slot_index >= inventory.slots.size():
		inventory.current_slot_index = maxi(0, inventory.slots.size() - 1)
