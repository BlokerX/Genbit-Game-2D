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

	# Tworzymy kopię efektu przed skalowaniem, aby nigdy nie zmodyfikować współdzielonego zasobu .tres!
	var modified_effect: Effect = incoming_effect.duplicate(true) as Effect
	modified_effect.source_entity = incoming_effect.source_entity
	modified_effect.source_position = incoming_effect.source_position

	if not is_equal_approx(total_duration_mult, 1.0):
		modified_effect.apply_duration_multiplier(maxf(MIN_EFFECT_MULTIPLIER, total_duration_mult))
	if not is_equal_approx(total_potency_mult, 1.0):
		modified_effect.apply_potency_multiplier(maxf(MIN_EFFECT_MULTIPLIER, total_potency_mult))

	return modified_effect

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
			if (
				component is PassiveItemComponent
				and component.requirement == PassiveItemComponent.PassiveRequirement.INVENTORY
			):
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
