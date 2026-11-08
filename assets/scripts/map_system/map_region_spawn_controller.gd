class_name MapRegionSpawnController
extends RefCounted
## Kontroler odpowiedzialny za jednorazowe wykonanie spawnu Reżysera (Director) przy wejściu do pokoju
## oraz za automatyczne wypełnienie skrzyń postawionych ręcznie na mapie (Hybrid Containers).

const ITEM_PICKUP_SCENE: PackedScene = preload("res://assets/scenes/game_objects/item_pickup.tscn")
const LOOSE_ITEM_SCATTER_PX: float = 15.0
const MIN_HYBRID_CHEST_ROLLS: int = 2
const MAX_HYBRID_CHEST_ROLLS: int = 4
const DIRECTOR_ONLY_TRIGGER_MODE: int = 0

func spawn_region(region: MapRegion) -> void:
	_run_director_spawner(region)
	_fill_hybrid_containers(region, region)

func _run_director_spawner(region: MapRegion) -> void:
	print("[Reżyser MapRegion] %s: Rozpoczynam procedurę spawnowania obiektów." % region.name)

	var entities_node: Node = region.find_child("Entities")
	var parent_node: Node = entities_node if entities_node != null else region

	# 1. Klasyczne markery wrogów (EnemySpawn)
	if region.enemy_pool != null:
		var old_enemy_spawns_count: int = 0
		for marker in region.enemy_spawns:
			if not marker.is_in_group("AdvancedSpawner") and randf() <= region.enemy_spawn_chance:
				var scene: PackedScene = region.enemy_pool.get_random_enemy_scene()
				_instantiate_scene(region, scene, marker.global_position, parent_node)
				old_enemy_spawns_count += 1
		if old_enemy_spawns_count > 0:
			print("[Reżyser MapRegion] Klasyczny system wygenerował %d wrogów." % old_enemy_spawns_count)

	# 2. Klasyczne markery obiektów fizycznych (ObjectSpawn)
	if region.object_pool != null:
		for marker in region.object_spawns:
			if not marker.is_in_group("AdvancedSpawner") and randf() <= region.object_spawn_chance:
				var scene: PackedScene = region.object_pool.get_random_object_scene()
				_instantiate_scene(region, scene, marker.global_position, parent_node)

	# 3. Klasyczne markery przedmiotów (ItemSpawn) - z ochroną RayCast przed ścianami!
	if region.item_pool != null:
		for marker in region.item_spawns:
			if not marker.is_in_group("AdvancedSpawner") and randf() <= region.item_spawn_chance:
				var entry: ItemLootEntry = region.item_pool.get_random_entry()
				if entry != null and entry.item_data != null:
					var stacks_count: int = entry.roll_slots_count()
					for _stack_idx in range(stacks_count):
						var pickup: ItemPickup = ITEM_PICKUP_SCENE.instantiate() as ItemPickup
						pickup.item = entry.create_item_instance()
						var random_offset: Vector2 = Vector2(
							randf_range(-LOOSE_ITEM_SCATTER_PX, LOOSE_ITEM_SCATTER_PX),
							randf_range(-LOOSE_ITEM_SCATTER_PX, LOOSE_ITEM_SCATTER_PX)
						)
						var safe_pos: Vector2 = ItemPickup.calculate_safe_spawn_position(
							marker.global_position,
							marker.global_position + random_offset,
							marker
						)
						_instantiate_node(region, pickup, safe_pos, parent_node)

	# 4. Zaawansowane spawnery ustawione na tryb DIRECTOR_ONLY
	var active_director_spawners: int = 0
	for child in region.find_children("*", "Marker2D", true, false):
		if not child.is_in_group("AdvancedSpawner"):
			continue
		if int(child.get("trigger_mode")) == DIRECTOR_ONLY_TRIGGER_MODE:
			active_director_spawners += 1
			print("[Reżyser MapRegion] Odpalam zaawansowany spawner: %s" % child.name)
			if child.has_method("attempt_spawn"):
				child.attempt_spawn()

	if active_director_spawners > 0:
		print(
			"[Reżyser MapRegion] Zakończono delegowanie zadań do %d zaawansowanych spawnerów."
			% active_director_spawners
		)

## Wypełnia losowym łupem skrzynie postawione ręcznie w edytorze wewnątrz pokoju.
func _fill_hybrid_containers(region: MapRegion, node: Node) -> void:
	for child in node.get_children():
		var storage: StorageComponent = child.get_node_or_null("StorageComponent") as StorageComponent
		if storage != null and not child.has_meta("is_filled_by_director"):
			child.set_meta("is_filled_by_director", true)
			if region.item_pool != null:
				var rolls_to_make: int = randi_range(MIN_HYBRID_CHEST_ROLLS, MAX_HYBRID_CHEST_ROLLS)
				var generated_loot: Array[ItemInstance] = []
				for _roll in range(rolls_to_make):
					var entry: ItemLootEntry = region.item_pool.get_random_entry()
					if entry == null or entry.item_data == null:
						continue
					var duplicated_entries: int = entry.roll_slots_count()
					for _entry_index in range(duplicated_entries):
						generated_loot.append(entry.create_item_instance())

				for item_instance in generated_loot:
					var empty_slot_indexes: Array[int] = []
					for slot_index in range(storage.slots.size()):
						var slot: SlotData = storage.slots[slot_index]
						if slot != null and slot.is_empty():
							empty_slot_indexes.append(slot_index)

					if not empty_slot_indexes.is_empty():
						var random_idx: int = randi_range(0, empty_slot_indexes.size() - 1)
						var chosen_slot_index: int = empty_slot_indexes[random_idx]
						storage.slots[chosen_slot_index].item = item_instance
					elif storage.has_method("insert_instance"):
						storage.insert_instance(item_instance)

		if child.get_child_count() > 0:
			_fill_hybrid_containers(region, child)

func _instantiate_scene(
	region: MapRegion, scene: PackedScene, position: Vector2, parent: Node
) -> void:
	if scene == null:
		return
	_instantiate_node(region, scene.instantiate(), position, parent)

func _instantiate_node(
	region: MapRegion, instance: Node, position: Vector2, parent: Node
) -> void:
	if "global_position" in instance:
		instance.global_position = position
	parent.add_child(instance)
	if "global_position" in instance:
		instance.global_position = position

	if region.map_region_type == MapRegion.MapRegionType.OPEN_WORLD:
		var streamer: Node = region.get_node_or_null("WorldStreamer")
		if streamer != null and streamer.has_method("register_entity"):
			streamer.register_entity(instance)
