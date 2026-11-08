class_name MapRegionSpawnController
extends RefCounted
## Kontroler odpowiedzialny za wykonanie spawnu Reżysera (Director) przy wejściu do pokoju
## oraz za automatyczne wypełnienie skrzyń postawionych ręcznie na mapie (Hybrid Containers).

const ITEM_PICKUP_SCENE: PackedScene = preload("res://assets/scenes/game_objects/item_pickup.tscn")
const LOOSE_ITEM_SCATTER_PX: float = 15.0
const MIN_HYBRID_CHEST_ROLLS: int = 2
const MAX_HYBRID_CHEST_ROLLS: int = 4
const DIRECTOR_ONLY_TRIGGER_MODE: int = 0
const MAX_SPAWN_FRAME_BUDGET_MSEC: int = 6

func spawn_region(region: MapRegion) -> void:
	_run_director_spawner(region)
	_fill_cached_hybrid_containers(region)

## Asynchroniczna wersja spawnowania dla ogromnych poziomów (nie blokuje okna gry przy setkach spawnerów).
func spawn_region_async(region: MapRegion, tree: SceneTree) -> void:
	await _run_director_spawner_async(region, tree)
	await _fill_cached_hybrid_containers_async(region, tree)

func _run_director_spawner_async(region: MapRegion, tree: SceneTree) -> void:
	print("[Reżyser MapRegion] %s: Rozpoczynam procedurę spawnowania obiektów." % region.name)

	var entities_node: Node = region.find_child("Entities")
	var parent_node: Node = entities_node if entities_node != null else region
	var frame_start_msec: int = Time.get_ticks_msec()

	if region.enemy_pool != null:
		for marker in region.enemy_spawns:
			if is_instance_valid(marker) and not marker.is_in_group("AdvancedSpawner") and randf() <= region.enemy_spawn_chance:
				var scene: PackedScene = region.enemy_pool.get_random_enemy_scene()
				_instantiate_scene(region, scene, marker.global_position, parent_node)
				if tree != null and Time.get_ticks_msec() - frame_start_msec >= MAX_SPAWN_FRAME_BUDGET_MSEC:
					await tree.process_frame
					frame_start_msec = Time.get_ticks_msec()

	if region.object_pool != null:
		for marker in region.object_spawns:
			if is_instance_valid(marker) and not marker.is_in_group("AdvancedSpawner") and randf() <= region.object_spawn_chance:
				var scene: PackedScene = region.object_pool.get_random_object_scene()
				_instantiate_scene(region, scene, marker.global_position, parent_node)
				if tree != null and Time.get_ticks_msec() - frame_start_msec >= MAX_SPAWN_FRAME_BUDGET_MSEC:
					await tree.process_frame
					frame_start_msec = Time.get_ticks_msec()

	if region.item_pool != null:
		for marker in region.item_spawns:
			if is_instance_valid(marker) and not marker.is_in_group("AdvancedSpawner") and randf() <= region.item_spawn_chance:
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
				if tree != null and Time.get_ticks_msec() - frame_start_msec >= MAX_SPAWN_FRAME_BUDGET_MSEC:
					await tree.process_frame
					frame_start_msec = Time.get_ticks_msec()

	var active_director_spawners: int = 0
	for spawner_node in region.advanced_spawners:
		if not is_instance_valid(spawner_node):
			continue
		if int(spawner_node.get("trigger_mode")) == DIRECTOR_ONLY_TRIGGER_MODE:
			active_director_spawners += 1
			if spawner_node.has_method("attempt_spawn"):
				spawner_node.attempt_spawn()
			if tree != null and Time.get_ticks_msec() - frame_start_msec >= MAX_SPAWN_FRAME_BUDGET_MSEC:
				await tree.process_frame
				frame_start_msec = Time.get_ticks_msec()

	if active_director_spawners > 0:
		print(
			"[Reżyser MapRegion] Zakończono delegowanie zadań do %d zaawansowanych spawnerów."
			% active_director_spawners
		)

func _fill_cached_hybrid_containers_async(region: MapRegion, tree: SceneTree) -> void:
	if region.item_pool == null:
		return
	var frame_start_msec: int = Time.get_ticks_msec()
	for container in region.hybrid_storage_containers:
		_fill_single_hybrid_container(region, container)
		if tree != null and Time.get_ticks_msec() - frame_start_msec >= MAX_SPAWN_FRAME_BUDGET_MSEC:
			await tree.process_frame
			frame_start_msec = Time.get_ticks_msec()

func _run_director_spawner(region: MapRegion) -> void:
	print("[Reżyser MapRegion] %s: Rozpoczynam procedurę spawnowania obiektów." % region.name)

	var entities_node: Node = region.find_child("Entities")
	var parent_node: Node = entities_node if entities_node != null else region

	if region.enemy_pool != null:
		for marker in region.enemy_spawns:
			if is_instance_valid(marker) and not marker.is_in_group("AdvancedSpawner") and randf() <= region.enemy_spawn_chance:
				var scene: PackedScene = region.enemy_pool.get_random_enemy_scene()
				_instantiate_scene(region, scene, marker.global_position, parent_node)

	if region.object_pool != null:
		for marker in region.object_spawns:
			if is_instance_valid(marker) and not marker.is_in_group("AdvancedSpawner") and randf() <= region.object_spawn_chance:
				var scene: PackedScene = region.object_pool.get_random_object_scene()
				_instantiate_scene(region, scene, marker.global_position, parent_node)

	if region.item_pool != null:
		for marker in region.item_spawns:
			if is_instance_valid(marker) and not marker.is_in_group("AdvancedSpawner") and randf() <= region.item_spawn_chance:
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

	for spawner_node in region.advanced_spawners:
		if not is_instance_valid(spawner_node):
			continue
		if int(spawner_node.get("trigger_mode")) == DIRECTOR_ONLY_TRIGGER_MODE:
			if spawner_node.has_method("attempt_spawn"):
				spawner_node.attempt_spawn()

func _fill_cached_hybrid_containers(region: MapRegion) -> void:
	if region.item_pool == null:
		return
	for container in region.hybrid_storage_containers:
		_fill_single_hybrid_container(region, container)

func _fill_single_hybrid_container(region: MapRegion, container: Node) -> void:
	if not is_instance_valid(container) or container.has_meta("is_filled_by_director"):
		return
	var storage: StorageComponent = container.get_node_or_null("StorageComponent") as StorageComponent
	if storage == null:
		return

	container.set_meta("is_filled_by_director", true)
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
