class_name MapRegionSpawnController
extends RefCounted

const ITEM_PICKUP_SCENE = preload("res://assets/scenes/game_objects/item_pickup.tscn")

func spawn_region(region: MapRegion) -> void:
	_run_director_spawner(region)
	_fill_hybrid_containers(region, region)

func _run_director_spawner(region: MapRegion) -> void:
	print("[Reżyser MapRegion] %s: Rozpoczynam procedurę spawnowania obiektów." % region.name)
	var entities_node := region.find_child("Entities")
	var parent_node: Node = entities_node if entities_node else region

	if region.enemy_pool != null:
		var old_enemy_spawns_count := 0
		for marker in region.enemy_spawns:
			if not marker.is_in_group("AdvancedSpawner") and randf() <= region.enemy_spawn_chance:
				var scene: PackedScene = region.enemy_pool.get_random_enemy_scene()
				_instantiate_scene(region, scene, marker.global_position, parent_node)
				old_enemy_spawns_count += 1
		if old_enemy_spawns_count > 0:
			print("[Reżyser MapRegion] Klasyczny system wygenerował %d wrogów." % old_enemy_spawns_count)

	if region.object_pool != null:
		for marker in region.object_spawns:
			if not marker.is_in_group("AdvancedSpawner") and randf() <= region.object_spawn_chance:
				var scene: PackedScene = region.object_pool.get_random_object_scene()
				_instantiate_scene(region, scene, marker.global_position, parent_node)

	if region.item_pool != null:
		for marker in region.item_spawns:
			if not marker.is_in_group("AdvancedSpawner") and randf() <= region.item_spawn_chance:
				var entry: ItemLootEntry = region.item_pool.get_random_entry()
				if entry != null and entry.item_data != null:
					var pickup := ITEM_PICKUP_SCENE.instantiate() as ItemPickup
					pickup.item = _create_instance_from_entry(entry)
					var random_offset := Vector2(randf_range(-15, 15), randf_range(-15, 15))
					_instantiate_node(
						region,
						pickup,
						marker.global_position + random_offset,
						parent_node
					)

	var active_director_spawners := 0
	for child in region.find_children("*", "Marker2D", true, false):
		if not child.is_in_group("AdvancedSpawner"):
			continue

		if child.get("trigger_mode") == 0:
			active_director_spawners += 1
			print("[Reżyser MapRegion] Odpalam zaawansowany spawner: %s" % child.name)
			if child.has_method("attempt_spawn"):
				child.attempt_spawn()

	if active_director_spawners > 0:
		print(
			"[Reżyser MapRegion] Zakończono delegowanie zadań do %d zaawansowanych spawnerów."
			% active_director_spawners
		)

func _fill_hybrid_containers(region: MapRegion, node: Node) -> void:
	for child in node.get_children():
		var storage: StorageComponent = child.get_node_or_null("StorageComponent")
		if storage != null and not child.has_meta("is_filled_by_director"):
			child.set_meta("is_filled_by_director", true)

			if region.item_pool != null:
				var rolls_to_make := randi_range(2, 4)
				var generated_loot: Array[ItemInstance] = []

				for _roll in range(rolls_to_make):
					var entry: ItemLootEntry = region.item_pool.get_random_entry()
					if entry == null or entry.item_data == null:
						continue

					var duplicated_entries: int = max(1, randi_range(entry.min_slots, entry.max_slots))
					for _entry_index in range(duplicated_entries):
						generated_loot.append(_create_instance_from_entry(entry))

				for item_instance in generated_loot:
					var empty_slot_indexes: Array[int] = []
					for slot_index in range(storage.slots.size()):
						var slot: SlotData = storage.slots[slot_index]
						if slot != null and slot.is_empty():
							empty_slot_indexes.append(slot_index)

					if not empty_slot_indexes.is_empty():
						var random_slot_index: int = empty_slot_indexes.pick_random()
						storage.slots[random_slot_index].item = item_instance
					elif storage.has_method("insert_instance"):
						storage.insert_instance(item_instance)

		if child.get_child_count() > 0:
			_fill_hybrid_containers(region, child)

func _instantiate_scene(
	region: MapRegion,
	scene: PackedScene,
	position: Vector2,
	parent: Node
) -> void:
	if scene == null:
		return
	_instantiate_node(region, scene.instantiate(), position, parent)

func _instantiate_node(
	region: MapRegion,
	instance: Node,
	position: Vector2,
	parent: Node
) -> void:
	parent.add_child(instance)
	if "global_position" in instance:
		instance.global_position = position

	if region.map_region_type == MapRegion.MapRegionType.OPEN_WORLD:
		var streamer = region.get_node_or_null("WorldStreamer")
		if streamer != null and streamer.has_method("register_entity"):
			streamer.register_entity(instance)

func _create_instance_from_entry(entry: ItemLootEntry) -> ItemInstance:
	var unique_data: ItemData = entry.item_data.duplicate(true)
	var amount: int = randi_range(entry.min_amount, entry.max_amount)
	var instance := ItemInstance.new(unique_data, amount)
	var max_durability := 0

	if unique_data.components != null:
		for component in unique_data.components:
			if component is DurabilityComponent:
				max_durability = component.max_durability
				break

	if entry.randomize_durability and max_durability > 0:
		var new_durability := max_durability
		if entry.durability_mode == ItemLootEntry.DurabilityRollMode.PERCENTAGE:
			var durability_percent := randf_range(
				entry.min_durability_percent,
				entry.max_durability_percent
			)
			new_durability = int(float(max_durability) * durability_percent)
		else:
			new_durability = randi_range(
				entry.min_exact_durability,
				entry.max_exact_durability
			)

		instance.state["durability"] = clampi(new_durability, 1, max_durability)

	return instance
