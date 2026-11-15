class_name InventoryPassiveController
extends RefCounted
## Kontroler zarządzający pasywnymi efektami ekwipunku oraz ewaluacją komponentów ochronnych (ProtectiveItemComponent).
## Realizuje zasady Single Responsibility (SRP) oraz Don't Repeat Yourself (DRY).

enum Change {
	HELD,
	EQUIPMENT,
	INVENTORY,
}

const FULL_PROTECTION_SCORE: float = 1.0
const MIN_EFFECT_MULTIPLIER: float = 0.05

var _last_held_signature: String = ""
var _last_equipment_signature: String = ""
var _last_inventory_signature: String = ""

## Zwraca listę pasywnych efektów z przedmiotu trzymanego aktualnie w dłoni.
func get_held_passives(inventory: Inventory) -> Array[Effect]:
	var active_effects: Array[Effect] = []
	var held_slot: SlotData = inventory.get_current_slot()
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

## Zwraca listę pasywnych efektów ze wszystkich założonych elementów zbroi i akcesoriów.
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

## Zwraca listę pasywnych efektów z przedmiotów znajdujących się w slotach plecaka.
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

## Przepuszcza przychodzący efekt przez wszystkie aktywne komponenty ochronne w ekwipunku, zbroi i dłoni.
## Zwraca zmodyfikowany (sklonowany) efekt lub null, jeśli efekt został całkowicie zablokowany.
func preprocess_incoming_effect(inventory: Inventory, incoming_effect: Effect) -> Effect:
	if inventory == null or incoming_effect == null:
		return incoming_effect

	var total_duration_mult: float = 1.0
	var total_potency_mult: float = 1.0
	var was_modified: bool = false

	var entries: Array[Dictionary] = _collect_all_item_contexts(inventory)
	for entry in entries:
		var item_inst: ItemInstance = entry["item"]
		var is_eq: bool = entry["is_equipped"]
		var is_held: bool = entry["is_held"]
		var is_inv: bool = entry["is_in_inventory"]

		for comp in item_inst.data.components:
			if comp == null:
				continue
			var eval_res: Dictionary = comp.evaluate_effect_protection(
				item_inst, incoming_effect, is_eq, is_held, is_inv
			)
			if bool(eval_res.get("blocked", false)):
				print("Ekwipunek (Ochrona): Zablokowano efekt '", incoming_effect.effect_name, "' dzięki [", item_inst.data.item_name, "]!")
				return null
			if bool(eval_res.get("modified", false)):
				total_duration_mult *= float(eval_res.get("duration_multiplier", 1.0))
				total_potency_mult *= float(eval_res.get("potency_multiplier", 1.0))
				was_modified = true

	if not was_modified:
		return incoming_effect

	if total_duration_mult <= 0.0 or total_potency_mult <= 0.0:
		print("Ekwipunek (Ochrona): Zredukowano efekt '", incoming_effect.effect_name, "' do zera!")
		return null

	var modified_effect: Effect = incoming_effect.duplicate(true) as Effect
	modified_effect.source_entity = incoming_effect.source_entity
	modified_effect.source_position = incoming_effect.source_position
	for meta_key in incoming_effect.get_meta_list():
		modified_effect.set_meta(meta_key, incoming_effect.get_meta(meta_key))

	if not is_equal_approx(total_duration_mult, 1.0):
		modified_effect.apply_duration_multiplier(maxf(MIN_EFFECT_MULTIPLIER, total_duration_mult))
	if not is_equal_approx(total_potency_mult, 1.0):
		modified_effect.apply_potency_multiplier(maxf(MIN_EFFECT_MULTIPLIER, total_potency_mult))

	return modified_effect

## Usuwa z kontenera effects_collector te obecnie trwające efekty, dla których aktywny przedmiot
## posiada regułę ochronną z włączoną opcją clear_existing_active_effects = true.
func purge_protected_active_effects(inventory: Inventory, effects_collector: Node) -> void:
	if inventory == null or not is_instance_valid(effects_collector):
		return

	var entries: Array[Dictionary] = _collect_all_item_contexts(inventory)
	if entries.is_empty():
		return

	for active_child in effects_collector.get_children():
		if not is_instance_valid(active_child) or active_child.is_queued_for_deletion():
			continue
		var eff_res: Effect = active_child.get("effect_resource") as Effect
		if eff_res == null:
			continue
		# Nie usuwamy własnych pasywnych efektów tego samego przedmiotu
		if eff_res.has_meta("passive_source"):
			continue

		var should_purge: bool = false
		var purging_item_name: String = ""

		for entry in entries:
			var item_inst: ItemInstance = entry["item"]
			var is_eq: bool = entry["is_equipped"]
			var is_held: bool = entry["is_held"]
			var is_inv: bool = entry["is_in_inventory"]

			for comp in item_inst.data.components:
				if comp != null and comp.should_purge_active_effect(item_inst, eff_res, is_eq, is_held, is_inv):
					should_purge = true
					purging_item_name = item_inst.data.item_name
					break
			if should_purge:
				break

		if should_purge:
			active_child.set_process(false)
			if active_child.has_method("end_effect"):
				active_child.end_effect()
			else:
				active_child.queue_free()
			if active_child.get_parent() == effects_collector:
				effects_collector.remove_child(active_child)
			print("Ekwipunek (Ochrona): Natychmiast usunięto trwający efekt '", eff_res.effect_name, "' dzięki [", purging_item_name, "]!")

## Oblicza łączną odporność (0.0 - 1.0) na podaną akcję specjalną (np. &"steal") ze wszystkich przedmiotów.
func get_total_action_protection(inventory: Inventory, action_tag: StringName) -> float:
	if inventory == null or action_tag == &"":
		return 0.0

	var combined_vulnerability: float = 1.0
	var entries: Array[Dictionary] = _collect_all_item_contexts(inventory)

	for entry in entries:
		var item_inst: ItemInstance = entry["item"]
		var is_eq: bool = entry["is_equipped"]
		var is_held: bool = entry["is_held"]
		var is_inv: bool = entry["is_in_inventory"]

		for comp in item_inst.data.components:
			if comp == null:
				continue
			var score: float = clampf(
				comp.get_action_protection_score(item_inst, action_tag, is_eq, is_held, is_inv),
				0.0,
				FULL_PROTECTION_SCORE
			)
			if score >= FULL_PROTECTION_SCORE:
				return FULL_PROTECTION_SCORE
			if score > 0.0:
				combined_vulnerability *= (1.0 - score)

	return clampf(1.0 - combined_vulnerability, 0.0, FULL_PROTECTION_SCORE)

## Sprawdza, czy dany egzemplarz przedmiotu posiada komponent blokujący jego własną kradzież.
func is_item_theft_protected(item_instance: ItemInstance) -> bool:
	if item_instance == null or item_instance.data == null:
		return false
	if item_instance.state.get("cannot_be_stolen", false) == true:
		return true
	if item_instance.data.components != null:
		for comp in item_instance.data.components:
			if comp != null and not comp.can_item_be_stolen(item_instance):
				return true
	return false

## Wyszukuje najsilniejszy aktywny LightSourceComponent spośród przedmiotu w dłoni, slotów zbroi/akcesoriów (np. Accessory) oraz plecaka.
func get_active_light_source(inventory: Inventory) -> LightSourceComponent:
	if inventory == null:
		return null

	var best_light: LightSourceComponent = null
	var best_energy: float = -1.0
	var entries: Array[Dictionary] = _collect_all_item_contexts(inventory)

	for entry in entries:
		var item_inst: ItemInstance = entry["item"]
		var is_eq: bool = entry["is_equipped"]
		var is_held: bool = entry["is_held"]
		var is_inv: bool = entry["is_in_inventory"]

		for comp in item_inst.data.components:
			if comp is LightSourceComponent:
				var light_comp: LightSourceComponent = comp as LightSourceComponent
				if light_comp.is_light_active_in_context(is_eq, is_held, is_inv):
					if light_comp.light_energy > best_energy:
						best_energy = light_comp.light_energy
						best_light = light_comp

	return best_light

## Zbiera listę wszystkich niepustych przedmiotów wraz z flagami ich kontekstu (zbroja, dłoń, plecak) - DRY.
func _collect_all_item_contexts(inventory: Inventory) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var held_slot: SlotData = inventory.get_current_slot()

	for slot_type in inventory.equipment_slots:
		var eq_slot: SlotData = inventory.equipment_slots[slot_type]
		if eq_slot != null and not eq_slot.is_empty() and eq_slot.item.data != null and eq_slot.item.data.components != null:
			results.append({
				"item": eq_slot.item,
				"is_equipped": true,
				"is_held": false,
				"is_in_inventory": false
			})

	for inv_slot in inventory.slots:
		if inv_slot != null and not inv_slot.is_empty() and inv_slot.item.data != null and inv_slot.item.data.components != null:
			results.append({
				"item": inv_slot.item,
				"is_equipped": false,
				"is_held": (inv_slot == held_slot),
				"is_in_inventory": true
			})

	return results

## Sprawdza zmiany w podpisach przedmiotów pasywnych i ochronnych, aby odświeżyć stan na postaci.
func check_for_changes(inventory: Inventory) -> Dictionary:
	var changes: Dictionary = {}

	var held_item: ItemInstance = inventory.get_current_item()
	var held_signature: String = ""
	if held_item != null:
		held_signature = (
			str(held_item.data.item_id) + ":" + str(held_item.state.get("amount", 1))
		)
	if held_signature != _last_held_signature:
		_last_held_signature = held_signature
		changes[Change.HELD] = true

	var inventory_signature: String = ""
	for slot in inventory.slots:
		if slot.is_empty() or slot.item.data.components == null:
			continue
		for component in slot.item.data.components:
			if component is PassiveItemComponent or component is ProtectiveItemComponent:
				inventory_signature += (
					str(slot.item.data.item_id) + ":" + str(slot.item.state.get("amount", 1)) + "|"
				)
	if inventory_signature != _last_inventory_signature:
		_last_inventory_signature = inventory_signature
		changes[Change.INVENTORY] = true

	var equipment_signature: String = ""
	for slot_type in inventory.equipment_slots:
		var slot_data: SlotData = inventory.equipment_slots[slot_type]
		if not slot_data.is_empty():
			equipment_signature += (
				str(slot_type) + ":" + str(slot_data.item.data.item_id) + "|"
			)
	if equipment_signature != _last_equipment_signature:
		_last_equipment_signature = equipment_signature
		changes[Change.EQUIPMENT] = true

	return changes
