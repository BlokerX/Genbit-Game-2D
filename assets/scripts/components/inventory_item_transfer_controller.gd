class_name InventoryItemTransferController
extends RefCounted
## Kontroler obsługujący dodawanie instancji oraz danych przedmiotów do slotów ekwipunku (z priorytetem uzupełniania stosów).

## Dodaje istniejącą instancję łącząc ją z kompatybilnymi stosami przed zajęciem pustego slotu.
func add_instance(inventory: Inventory, instance_to_add: ItemInstance) -> ItemInstance:
	if instance_to_add == null:
		return null
	if instance_to_add.data == null:
		push_error("InventoryItemTransferController nie może dodać instancji bez ItemData.")
		return instance_to_add

	var add_amount: int = instance_to_add.state.get("amount", 1)
	if add_amount <= 0:
		return null

	var max_stack: int = instance_to_add.get_max_stack()
	var is_stackable: bool = max_stack > 1

	# 1. Jeśli przedmiot jest stackowalny, szukamy dla niego miejsca w istniejących stosach
	if is_stackable:
		for slot in inventory.slots:
			if not slot.is_empty() and slot.item.can_stack_with(instance_to_add):
				var slot_amount: int = slot.item.state.get("amount", 1)
				var available_space: int = max_stack - slot_amount

				if available_space > 0:
					var adding: int = mini(instance_to_add.state.get("amount", 1), available_space)
					slot.item.state["amount"] = slot_amount + adding
					instance_to_add.state["amount"] = instance_to_add.state.get("amount", 1) - adding
					inventory._update_cache(instance_to_add.data.item_id, adding)

					if instance_to_add.state["amount"] <= 0:
						inventory.inventory_updated.emit()
						return null

	# 2. Próbujemy wrzucić do slotu trzymanego aktualnie w dłoni (jeśli jest pusty)
	var current_slot: SlotData = inventory.get_current_slot()
	if current_slot != null and current_slot.is_empty():
		current_slot.item = instance_to_add
		inventory._update_cache(instance_to_add.data.item_id, instance_to_add.state.get("amount", 1))
		inventory.inventory_updated.emit()
		return null

	# 3. Szukamy jakiegokolwiek innego pustego slota od lewej
	for slot in inventory.slots:
		if slot.is_empty():
			slot.item = instance_to_add
			inventory._update_cache(instance_to_add.data.item_id, instance_to_add.state.get("amount", 1))
			inventory.inventory_updated.emit()
			return null

	# 4. Całkowity brak miejsca - zwracamy instancję z powrotem na ziemię
	inventory.inventory_updated.emit()
	return instance_to_add

## Tworzy przedmioty na podstawie danych, najpierw uzupełniając stosy, a potem puste sloty.
func add_item(inventory: Inventory, item: ItemData, amount_to_add: int = 1) -> int:
	if item == null or amount_to_add <= 0:
		return amount_to_add

	var remaining: int = amount_to_add
	var temp_instance: ItemInstance = ItemInstance.new(item, 1)
	var max_item_stack: int = temp_instance.get_max_stack()
	var is_stackable: bool = max_item_stack > 1

	# 1. Szukanie w stosach
	if is_stackable:
		for slot in inventory.slots:
			if not slot.is_empty() and slot.item.can_stack_with(temp_instance):
				var slot_amount: int = slot.item.state.get("amount", 1)
				var available_space: int = max_item_stack - slot_amount

				if available_space > 0:
					var adding: int = mini(remaining, available_space)
					slot.item.state["amount"] = slot_amount + adding
					remaining -= adding
					inventory._update_cache(item.item_id, adding)

					if remaining == 0:
						inventory.inventory_updated.emit()
						return 0

	# 2. Szukanie pustego miejsca w aktualnie wybranej ręce
	var current_slot: SlotData = inventory.get_current_slot()
	if current_slot != null and current_slot.is_empty():
		var adding: int = mini(remaining, max_item_stack) if is_stackable else 1
		current_slot.set_item_data(item, adding)
		remaining -= adding
		inventory._update_cache(item.item_id, adding)
		if remaining == 0:
			inventory.inventory_updated.emit()
			return 0

	# 3. Szukanie dowolnego pustego slotu od lewej
	for slot in inventory.slots:
		if slot.is_empty():
			var adding: int = mini(remaining, max_item_stack) if is_stackable else 1
			slot.set_item_data(item, adding)
			remaining -= adding
			inventory._update_cache(item.item_id, adding)
			if remaining == 0:
				inventory.inventory_updated.emit()
				return 0

	# 4. Brak miejsca na resztę
	inventory.inventory_updated.emit()
	return remaining
