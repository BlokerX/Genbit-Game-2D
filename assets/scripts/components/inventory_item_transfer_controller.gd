class_name InventoryItemTransferController
extends RefCounted

## Dodaje istniejącą instancję, łącząc ją z kompatybilnymi stosami przed zajęciem pustego slotu.
func add_instance(inventory: Inventory, instance_to_add: ItemInstance) -> ItemInstance:
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
		for slot in inventory.slots:
			if not slot.is_empty() and slot.item.can_stack_with(instance_to_add):
				var slot_amount = slot.item.state.get("amount", 1)
				var available_space = max_stack - slot_amount

				if available_space > 0:
					var adding = min(instance_to_add.state.get("amount", 1), available_space)

					# Aktualizujemy stany obu przedmiotów
					slot.item.state["amount"] = slot_amount + adding
					instance_to_add.state["amount"] = instance_to_add.state.get("amount", 1) - adding

					# Rejestrujemy to w pamięci craftingu
					inventory._update_cache(instance_to_add.data.item_id, adding)

					if instance_to_add.state["amount"] <= 0:
						inventory.inventory_updated.emit()
						return null # Całość się zmieściła, kończymy pracę

	# 4. Jeśli przedmiot nie jest stackowalny, lub zostały nam resztki:
	# Próbujemy wrzucić do slotu trzymanego aktualnie w dłoni (jeśli jest pusty)
	var current_slot = inventory.get_current_slot()
	if current_slot != null and current_slot.is_empty():
		current_slot.item = instance_to_add
		inventory._update_cache(instance_to_add.data.item_id, instance_to_add.state.get("amount", 1))
		inventory.inventory_updated.emit()
		return null

	# 5. Szukamy jakiegokolwiek innego pustego slota od lewej
	for slot in inventory.slots:
		if slot.is_empty():
			slot.item = instance_to_add
			inventory._update_cache(instance_to_add.data.item_id, instance_to_add.state.get("amount", 1))
			inventory.inventory_updated.emit()
			return null

	# 6. Całkowity brak miejsca - zwracamy instancję z powrotem na ziemię
	inventory.inventory_updated.emit()
	return instance_to_add

## Tworzy przedmioty na podstawie danych, najpierw uzupełniając stosy, a potem puste sloty.
func add_item(inventory: Inventory, item: ItemData, amount_to_add: int = 1) -> int:
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
		for slot in inventory.slots:
			if not slot.is_empty() and slot.item.can_stack_with(temp_instance):
				var slot_amount = slot.item.state.get("amount", 1)
				var available_space = max_item_stack - slot_amount

				if available_space > 0:
					var adding = min(remaining, available_space)
					slot.item.state["amount"] = slot_amount + adding
					remaining -= adding

					inventory._update_cache(item.item_id, adding)

					if remaining == 0:
						inventory.inventory_updated.emit()
						return 0

	# 2. Szukanie pustych w wybranej ręce
	var current_slot = inventory.get_current_slot()
	if current_slot != null and current_slot.is_empty():
		var adding = min(remaining, max_item_stack) if is_stackable else 1
		current_slot.set_item_data(item, adding)
		remaining -= adding
		inventory._update_cache(item.item_id, adding)
		if remaining == 0:
			inventory.inventory_updated.emit()
			return 0

	# 3. Szukanie dowolnego pustego od lewej
	for slot in inventory.slots:
		if slot.is_empty():
			var adding = min(remaining, max_item_stack) if is_stackable else 1
			slot.set_item_data(item, adding)
			remaining -= adding
			inventory._update_cache(item.item_id, adding)
			if remaining == 0:
				inventory.inventory_updated.emit()
				return 0

	# 4. Jeśli zabrakło miejsca w całym ekwipunku, zwracamy to, co nam zostało w dłoni
	inventory.inventory_updated.emit()
	return remaining
