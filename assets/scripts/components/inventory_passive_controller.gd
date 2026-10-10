class_name InventoryPassiveController
extends RefCounted

enum Change {
	HELD,
	EQUIPMENT,
	INVENTORY,
}

var _last_held_signature: String = ""
var _last_equipment_signature: String = ""
var _last_inventory_signature: String = ""

func get_held_passives(inventory: Inventory) -> Array[Effect]:
	var active_effects: Array[Effect] = []
	var held_slot := inventory.get_current_slot()
	if held_slot == null or held_slot.is_empty() or held_slot.item.data.components == null:
		return active_effects

	for component in held_slot.item.data.components:
		if (
			component is PassiveItemComponent
			and component.requirement == PassiveItemComponent.PassiveRequirement.HELD
		):
			var count: int = (
				held_slot.item.state.get("amount", 1)
				if component.stack_effects_with_amount
				else 1
			)
			for _index in range(count):
				active_effects.append_array(component.passive_buffs)

	return active_effects

func get_equipment_passives(inventory: Inventory) -> Array[Effect]:
	var active_effects: Array[Effect] = []
	for slot_type in inventory.equipment_slots:
		var slot_data: SlotData = inventory.equipment_slots[slot_type]
		if slot_data.is_empty() or slot_data.item.data.components == null:
			continue

		for component in slot_data.item.data.components:
			if (
				component is EquippableComponent
				and component.equip_slot_type == slot_type
			):
				active_effects.append_array(component.passive_buffs)

	return active_effects

func get_inventory_passives(inventory: Inventory) -> Array[Effect]:
	var active_effects: Array[Effect] = []
	for slot_data in inventory.slots:
		if slot_data.is_empty() or slot_data.item.data.components == null:
			continue

		for component in slot_data.item.data.components:
			if (
				component is PassiveItemComponent
				and component.requirement == PassiveItemComponent.PassiveRequirement.INVENTORY
			):
				var count: int = (
					slot_data.item.state.get("amount", 1)
					if component.stack_effects_with_amount
					else 1
				)
				for _index in range(count):
					active_effects.append_array(component.passive_buffs)

	return active_effects

func check_for_changes(inventory: Inventory) -> Dictionary:
	var changes := {}
	var held_item := inventory.get_current_item()
	var held_signature := ""
	if held_item != null:
		held_signature = (
			str(held_item.data.item_id)
			+ ":"
			+ str(held_item.state.get("amount", 1))
		)
	if held_signature != _last_held_signature:
		_last_held_signature = held_signature
		changes[Change.HELD] = true

	var inventory_signature := ""
	for slot in inventory.slots:
		if slot.is_empty() or slot.item.data.components == null:
			continue
		for component in slot.item.data.components:
			if (
				component is PassiveItemComponent
				and component.requirement == PassiveItemComponent.PassiveRequirement.INVENTORY
			):
				inventory_signature += (
					str(slot.item.data.item_id)
					+ ":"
					+ str(slot.item.state.get("amount", 1))
					+ "|"
				)
	if inventory_signature != _last_inventory_signature:
		_last_inventory_signature = inventory_signature
		changes[Change.INVENTORY] = true

	var equipment_signature := ""
	for slot_type in inventory.equipment_slots:
		var slot_data: SlotData = inventory.equipment_slots[slot_type]
		if not slot_data.is_empty():
			equipment_signature += (
				str(slot_type)
				+ ":"
				+ str(slot_data.item.data.item_id)
				+ "|"
			)
	if equipment_signature != _last_equipment_signature:
		_last_equipment_signature = equipment_signature
		changes[Change.EQUIPMENT] = true

	return changes
