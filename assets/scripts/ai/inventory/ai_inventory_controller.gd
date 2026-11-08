extends Node
class_name AIInventoryController

signal inventory_updated
signal item_dropped(dropped_instance: ItemInstance, is_thrown: bool)

@export_category("Konfiguracja AI")
## Jeśli prawda, AI nie zużywa fizycznych sztuk amunicji z plecaka.
## UWAGA: AI wciąż MUSI posiadać min. 1 paczkę amunicji na liście, aby broń wiedziała czym strzela!
@export var infinite_ammo: bool = true

## Jeśli prawda, broń zostanie automatycznie załadowana przy pojawieniu się wroga (wymaga min. 1 paczki).
@export var preload_weapon_on_start: bool = true
@export var starting_equipment: Array[AIInventoryEntry] = []

var items: Array[ItemInstance] = []
var current_item_index: int = 0

func _ready() -> void:
	for entry in starting_equipment:
		if entry != null and entry.item_data != null:
			# Wzorzec Flyweight (SOLID): Współdzielimy szablon ItemData zamiast klonować go przez duplicate(true)
			# dla każdego żołnierza na mapie! Cały zmienny stan broni siedzi w słowniku inst.state.
			var inst: ItemInstance = ItemInstance.new(entry.item_data, entry.amount)

			inst.state["drop_on_death"] = entry.drop_on_death
			inst.state["is_usable_by_ai"] = entry.is_usable_by_ai

			if inst.data.components != null:
				for comp in inst.data.components:
					if comp is DurabilityComponent:
						inst.state["durability"] = comp.max_durability

			items.append(inst)

	if preload_weapon_on_start and items.size() > 0:
		reload_current_weapon()

func get_current_item() -> ItemInstance:
	if items.is_empty() or current_item_index >= items.size():
		return null
	return items[current_item_index]

func reload_current_weapon() -> bool:
	var inst: ItemInstance = get_current_item()
	if not inst:
		return false

	var weapon_comp: RangedWeaponComponent = null
	if inst.data.components != null:
		for comp in inst.data.components:
			if comp is RangedWeaponComponent:
				weapon_comp = comp
				break

	if not weapon_comp or not weapon_comp.uses_ammunition:
		return false

	var found_ammo_id: StringName = &""
	var current_ammo: int = inst.state.get("ammo_count", 0)
	var ammo_needed: int = weapon_comp.magazine_capacity - current_ammo
	if ammo_needed <= 0:
		return false

	var ammo_found: int = 0

	for i in range(items.size()):
		var ammo_item: ItemInstance = items[i]
		if ammo_item == null or ammo_item.data == null:
			continue

		var a_comp: AmmunitionComponent = null
		if ammo_item.data.components != null:
			for c in ammo_item.data.components:
				if c is AmmunitionComponent:
					a_comp = c
					break

		if a_comp and a_comp.ammunition_type == weapon_comp.accepted_ammunition_type:
			found_ammo_id = ammo_item.data.item_id

			if infinite_ammo:
				ammo_found = ammo_needed
				break
			else:
				var available: int = ammo_item.state.get("amount", 1)
				var taking: int = mini(available, ammo_needed - ammo_found)
				ammo_item.state["amount"] = available - taking
				ammo_found += taking
				if ammo_found >= ammo_needed:
					break

	if ammo_found > 0:
		inst.state["ammo_count"] = current_ammo + ammo_found
		inst.state["ammo_id"] = found_ammo_id

		if not infinite_ammo:
			clean_dead_items()
		inventory_updated.emit()
		return true

	return false

func clean_dead_items() -> void:
	var changed: bool = false
	for i in range(items.size() - 1, -1, -1):
		if items[i].state.has("amount") and items[i].state["amount"] <= 0:
			items.remove_at(i)
			changed = true

	if current_item_index >= items.size():
		current_item_index = maxi(0, items.size() - 1)

	if changed:
		inventory_updated.emit()

func add_instance(instance: ItemInstance) -> ItemInstance:
	return instance

func drop_all_items(owner_entity: Node2D) -> void:
	var thrower = owner_entity.get_node_or_null("ItemThrowerComponent")

	for i in range(items.size() - 1, -1, -1):
		var item_inst: ItemInstance = items[i]
		if item_inst != null and item_inst.data != null:
			var should_drop: bool = item_inst.state.get("drop_on_death", true)

			if should_drop:
				if thrower:
					var random_dir: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
					thrower.handle_item_drop(owner_entity, item_inst, true, false, random_dir)
				else:
					print("Brak ItemThrowerComponent u wroga: ", owner_entity.name)

		items.remove_at(i)
