class_name InventorySlotInteractor
extends RefCounted

signal held_item_changed

var player_inventory: Inventory
var open_storage: Node
var held_item: ItemInstance

func initialize(inventory: Inventory) -> void:
	player_inventory = inventory

func handle_slot_clicked(parent_node: Node, slot_index: int, button_index: int) -> void:
	if DialogueManager.is_active:
		return

	var target_slot: SlotData
	if parent_node is StorageComponent:
		target_slot = parent_node.slots[slot_index]
	elif parent_node is Inventory:
		if slot_index <= -10:
			var equip_type = abs(slot_index + 10)
			target_slot = parent_node.equipment_slots[equip_type]
		else:
			target_slot = parent_node.slots[slot_index]
	else:
		return

	if button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(target_slot)
	elif button_index == MOUSE_BUTTON_RIGHT:
		if slot_index <= -10:
			_handle_left_click(target_slot)
		else:
			_handle_right_click(target_slot)
	elif button_index == -1:
		if slot_index <= -10:
			_handle_quick_unequip_accessory(abs(slot_index + 10))
		elif not _try_quick_equip(parent_node, slot_index) and open_storage != null:
			_handle_quick_transfer(parent_node, slot_index)

	held_item_changed.emit()
	if parent_node is StorageComponent:
		parent_node.storage_updated.emit()
	elif parent_node is Inventory:
		parent_node.inventory_updated.emit()

func _handle_left_click(slot: SlotData) -> void:
	var is_equipment_slot := false
	var accessory_type := -1
	if player_inventory != null:
		for key in player_inventory.equipment_slots:
			if slot == player_inventory.equipment_slots[key]:
				is_equipment_slot = true
				accessory_type = key
				break

	if is_equipment_slot:
		if held_item == null:
			if not slot.is_empty():
				held_item = player_inventory.unequip_item(accessory_type)
		else:
			var item_equip_type := -1
			if held_item.data.components != null:
				for component in held_item.data.components:
					if component is EquippableComponent:
						item_equip_type = component.equip_slot_type
						break
			if item_equip_type == accessory_type:
				var hand_amount = held_item.state.get("amount", 1)
				if hand_amount > 1:
					var unique_data = held_item.data.duplicate(true)
					var single_equipment = ItemInstance.new(unique_data, 1)
					if held_item.state.has("durability"):
						single_equipment.state["durability"] = held_item.state["durability"]
					held_item.state["amount"] = hand_amount - 1
					var old_equipment = player_inventory.equip_item(single_equipment, accessory_type)
					if old_equipment != null:
						var remainder = player_inventory.add_instance(old_equipment)
						if remainder != null:
							player_inventory.item_dropped.emit(remainder, false)
				else:
					held_item = player_inventory.equip_item(held_item, accessory_type)
			else:
				print("Ten przedmiot nie pasuje do tego slotu zbroi!")
		return

	if held_item == null:
		if not slot.is_empty():
			held_item = slot.item
			slot.clear_slot()
	elif slot.is_empty():
		slot.item = held_item
		held_item = null
	elif slot.item.can_stack_with(held_item):
		var max_stack = _get_max_stack(slot.item)
		var slot_amount = slot.item.state.get("amount", 1)
		var hand_amount = held_item.state.get("amount", 1)
		var available_space = max_stack - slot_amount
		if available_space > 0:
			var amount_to_add = min(available_space, hand_amount)
			slot.item.state["amount"] = slot_amount + amount_to_add
			held_item.state["amount"] = hand_amount - amount_to_add
			if held_item.state["amount"] <= 0:
				held_item = null
	else:
		var temp_item = slot.item
		slot.item = held_item
		held_item = temp_item

func _handle_right_click(slot: SlotData) -> void:
	if held_item == null:
		if not slot.is_empty():
			var slot_amount = slot.item.state.get("amount", 1)
			if slot_amount > 1:
				@warning_ignore("integer_division")
				var half_amount = int(slot_amount / 2)
				var unique_data = slot.item.data.duplicate(true)
				held_item = ItemInstance.new(unique_data, half_amount)
				held_item.state = slot.item.state.duplicate(true)
				held_item.state["amount"] = half_amount
				slot.item.state["amount"] = slot_amount - half_amount
			else:
				held_item = slot.item
				slot.clear_slot()
	elif slot.is_empty():
		var unique_data = held_item.data.duplicate(true)
		slot.item = ItemInstance.new(unique_data, 1)
		slot.item.state = held_item.state.duplicate(true)
		slot.item.state["amount"] = 1
		var hand_amount = held_item.state.get("amount", 1)
		held_item.state["amount"] = hand_amount - 1
		if held_item.state["amount"] <= 0:
			held_item = null
	elif slot.item.can_stack_with(held_item):
		var max_stack = _get_max_stack(slot.item)
		var slot_amount = slot.item.state.get("amount", 1)
		var hand_amount = held_item.state.get("amount", 1)
		if slot_amount < max_stack:
			slot.item.state["amount"] = slot_amount + 1
			held_item.state["amount"] = hand_amount - 1
			if held_item.state["amount"] <= 0:
				held_item = null

func _handle_quick_transfer(from_node: Node, slot_index: int) -> void:
	if open_storage == null or player_inventory == null:
		return
	if from_node is StorageComponent:
		var instance_to_move = from_node.remove_instance(slot_index)
		if instance_to_move != null:
			var remainder = player_inventory.add_instance(instance_to_move)
			if remainder != null:
				from_node.insert_instance(remainder)
	elif from_node is Inventory:
		var slot_data = from_node.slots[slot_index]
		if not slot_data.is_empty():
			var instance_to_move = slot_data.item
			slot_data.clear_slot()
			var remainder = open_storage.insert_instance(instance_to_move)
			if remainder != null:
				player_inventory.add_instance(remainder)

func _handle_quick_unequip_accessory(equip_type: int) -> void:
	if not player_inventory or player_inventory.equipment_slots[equip_type].is_empty():
		return
	var accessory_to_unequip = player_inventory.unequip_item(equip_type)
	var remainder = player_inventory.add_instance(accessory_to_unequip)
	if remainder != null:
		player_inventory.item_dropped.emit(remainder, false)
		print("Brak miejsca w ekwipunku! Zbroja upada na ziemię.")

func _try_quick_equip(from_node: Node, slot_index: int) -> bool:
	if not player_inventory:
		return false

	var slot_data: SlotData = null
	if from_node is Inventory:
		slot_data = from_node.slots[slot_index]
	elif from_node is StorageComponent:
		slot_data = from_node.slots[slot_index]
	if slot_data == null or slot_data.is_empty() or slot_data.item.data.components == null:
		return false

	for component in slot_data.item.data.components:
		if component is EquippableComponent:
			if player_inventory.equipment_slots[component.equip_slot_type].is_empty():
				var unique_data = slot_data.item.data.duplicate(true)
				var single_equipment = ItemInstance.new(unique_data, 1)
				single_equipment.state = slot_data.item.state.duplicate(true)
				single_equipment.state["amount"] = 1
				var slot_amount = slot_data.item.state.get("amount", 1)
				slot_data.item.state["amount"] = slot_amount - 1
				if slot_data.item.state["amount"] <= 0:
					slot_data.clear_slot()
				player_inventory.equip_item(single_equipment, component.equip_slot_type)
				if from_node is StorageComponent:
					from_node.storage_updated.emit()
				return true
	return false

static func _get_max_stack(item: ItemInstance) -> int:
	if item.data.components != null:
		for component in item.data.components:
			if component is StackComponent:
				return component.max_stack
	return 1
