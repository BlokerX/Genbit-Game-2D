extends Node2D
## Klasa poziomu, przechowująca pokoje (MapRegion) na poziomie i zarządzająca przejściami między nimi.
class_name Map

# --- STAŁE DOMENOWE (Wyeliminowanie magicznych liczb i stringów) ---
const PLAYER_GROUP: String = "Player"
const SLIDE_ANIMATION_DURATION_SEC: float = 0.45

const MapLightingControllerType = preload(
	"res://assets/scripts/map_system/map_lighting_controller.gd"
)
const MapDoorGeneratorType = preload(
	"res://assets/scripts/map_system/map_door_generator.gd"
)
const MapRegionEntryControllerType = preload(
	"res://assets/scripts/map_system/map_region_entry_controller.gd"
)

## Sygnał zmiany pokoju
signal map_region_changed(new_map_region: MapRegion)
## Sygnał aktualizacji mapy (UI)
signal map_updated()

@export_group("Ustawienia zapisu (Czy level jest zapamiętywany po wyjściu)")
## Jeśli TRUE: Pokoje wewnątrz tego poziomu będą zarządzane w pamięci RAM podczas sesji gry.
## Zabite potwory, zniszczone skrzynie i upuszczony loot ZOSTANĄ zachowane po wyjściu i powrocie na mapę.
## Jeśli FALSE: To jest nietrwały "Dungeon". Wszystko wraca do normy po wyjściu z mapy.
@export var is_persistent_level: bool = true

@export_group("Główne Obiekty")
## Pokój startowy
@export var starting_map_region: MapRegion

@export_group("Ustawienia Respawnu")
## Czy po respawnie wyczyścić historię odkrytych i odwiedzonych pokoi na minimapie?
@export var reset_map_history_on_respawn: bool = true
## Czy całkowicie zresetować poziom (przeładować aktualną scenę gry)?
@export var reload_entire_scene_on_respawn: bool = false

## Wewnętrzna zmienna systemowa: Gwarantuje, że RAM i Minimapa wiedzą, z jakiego pliku .tscn pochodzi ta mapa.
var source_level_path: String = ""

## Obecny pokój na scenie
var current_map_region: MapRegion
## Wszystkie pokoje
var all_map_regions: Array[MapRegion] = []
## Odkryte pokoje (widoczne na mapie)
var discovered_map_regions: Array[MapRegion] = []
## Pokoje odwiedzone
var visited_map_regions: Array[MapRegion] = []

## Słownik przestrzenny (Grid): Kluczem jest Vector2i, a wartością obiekt MapRegion
var map_region_grid: Dictionary = {}

## Węzeł zaciemniający całą planszę (sterowany płynnie przez MapLightingController)
var global_darkness: CanvasModulate
var _lighting_controller: MapLightingControllerType
var _door_generator: MapDoorGeneratorType
var _region_entry_controller: MapRegionEntryControllerType
var _is_transitioning: bool = false
var _pre_initialized: bool = false

@export_group("Generacja Drzwi")
## Scena drzwi, która ma być automatycznie wstawiana do pokoi
@export var auto_door_scene: PackedScene
## Domyślna tekstura drzwi dla CAŁEJ MAPY. 
@export var default_map_door_texture: Texture2D

## Wykonywane ZANIM dzieci (MapRegion i tysiące botów) wejdą do drzewa sceny!
func _enter_tree() -> void:
	if not _pre_initialized:
		prepare_map_before_tree(GlobalLevelManager.target_entrance_id)

## Przygotowuje strukturę pokoi i dzieli otwarty świat na chunki ZANIM mapa wejdzie do SceneTree.
## Dzięki temu nieaktywne pokoje oraz odległe chunki (np. Soldier1..1000) nigdy nie obciążają startu poziomu!
func prepare_map_before_tree(entrance_id: String = "") -> void:
	if _pre_initialized:
		return
	_pre_initialized = true

	_door_generator = MapDoorGeneratorType.new()
	_door_generator.configure(auto_door_scene, default_map_door_texture)

	var region_children: Array[MapRegion] = []
	for child in get_children():
		if child is MapRegion:
			var region: MapRegion = child as MapRegion
			region_children.append(region)
			register_map_region(region, false)
			region.prepare_region_before_tree(false)

	# 1. Spawnujemy brakujące drzwi i zszywamy siatkę pokoi w pamięci RAM
	_auto_spawn_missing_doors()
	_auto_link_doors()

	# 2. Ustalamy, w którym pokoju i w jakim punkcie pojawi się gracz
	var active_region: MapRegion = starting_map_region
	var focus_pos: Vector2 = Vector2.ZERO
	if entrance_id != "":
		var entrance: LevelEntrance = _find_entrance_by_id(entrance_id)
		if entrance != null:
			active_region = _get_map_region_of_node(entrance)
			focus_pos = entrance.position + (active_region.position if active_region != null else Vector2.ZERO)

	if active_region != null and focus_pos == Vector2.ZERO:
		if active_region.spawn_points.size() > 0:
			focus_pos = active_region.position + active_region.spawn_points[0].position
		else:
			focus_pos = active_region.position + (active_region.size_px / 2.0)

	# 3. Odpinamy wszystkie inne pokoje PRZED wejściem do SceneTree,
	# a dla pokoju aktywnego dzielimy encje na chunki wokół punktu startowego!
	for region in region_children:
		if region != active_region:
			if region.get_parent() == self:
				remove_child(region)
		else:
			region.prepare_region_before_tree(true, focus_pos)

func _ready() -> void:
	add_to_group("Map")

	# --- GLOBALNY MROK ---
	global_darkness = CanvasModulate.new()
	global_darkness.name = "GlobalDarkness"
	global_darkness.color = Color.WHITE
	add_child(global_darkness)
	_lighting_controller = MapLightingControllerType.new()
	_lighting_controller.initialize(global_darkness)
	if _door_generator == null:
		_door_generator = MapDoorGeneratorType.new()
		_door_generator.configure(auto_door_scene, default_map_door_texture)
	_region_entry_controller = MapRegionEntryControllerType.new()

	if not _pre_initialized:
		prepare_map_before_tree(GlobalLevelManager.target_entrance_id)

	map_updated.emit()
	initialize_level()

## Wprowadza mapę w stan hibernacji przed schowaniem jej do _cached_persistent_levels w RAM-ie.
func hibernate_for_cache() -> void:
	for region in all_map_regions:
		if is_instance_valid(region):
			var streamer: WorldStreamer = region.get_node_or_null("WorldStreamer") as WorldStreamer
			if streamer != null:
				streamer.hibernate_all_chunks()

func initialize_level() -> void:
	var map_region_to_load: MapRegion = starting_map_region
	var spawn_node: Node2D = null

	if GlobalLevelManager.target_entrance_id != "":
		var entrance: LevelEntrance = _find_entrance_by_id(GlobalLevelManager.target_entrance_id)
		if entrance != null:
			map_region_to_load = _get_map_region_of_node(entrance)
			spawn_node = entrance
			entrance.has_triggered = true
			GlobalLevelManager.register_arrival_entrance(entrance)
		else:
			push_error("Map: Nie znaleziono wejścia o ID: " + GlobalLevelManager.target_entrance_id)

		GlobalLevelManager.target_entrance_id = ""
	else:
		TransitionManager.color_rect.color = Color.BLACK

	if map_region_to_load != null:
		var target_focus_pos: Vector2 = Vector2.ZERO
		if spawn_node != null:
			target_focus_pos = spawn_node.global_position if spawn_node.is_inside_tree() else (map_region_to_load.position + spawn_node.position)
		elif map_region_to_load.spawn_points.size() > 0:
			target_focus_pos = map_region_to_load.position + map_region_to_load.spawn_points[0].position

		map_region_to_load.ensure_runtime_initialized(target_focus_pos)
		var streamer: WorldStreamer = map_region_to_load.get_node_or_null("WorldStreamer") as WorldStreamer
		if streamer != null:
			streamer.restore_active_chunks(target_focus_pos)

		if not map_region_to_load.is_inside_tree():
			add_child(map_region_to_load)
		_lighting_controller.apply_region(map_region_to_load)

		var player: PlayerCharacter = get_player()
		if player != null:
			if spawn_node != null:
				player.global_position = spawn_node.global_position
			elif map_region_to_load.spawn_points.size() > 0:
				player.global_position = map_region_to_load.spawn_points[0].global_position

		call_deferred("change_map_region", map_region_to_load, spawn_node, true)

## Funkcja pomocnicza: Szuka po ID wejścia na całej mapie
func _find_entrance_by_id(id: String) -> LevelEntrance:
	for map_region in all_map_regions:
		for child in map_region.find_children("*", "LevelEntrance", true, false):
			if child.my_entrance_id == id:
				return child as LevelEntrance
	return null

## Funkcja pomocnicza: Zwraca pokój, do którego należy dany węzeł
func _get_map_region_of_node(node: Node) -> MapRegion:
	var current: Node = node
	while current != null:
		if current is MapRegion:
			return current as MapRegion
		current = current.get_parent()
	return null

# --- FUNKCJE DYNAMIKI MAPY ---

func register_map_region(map_region: MapRegion, notify_ui: bool = true) -> void:
	if not all_map_regions.has(map_region):
		all_map_regions.append(map_region)
		map_region_grid[map_region.map_position] = map_region
		if notify_ui:
			map_updated.emit()

func unregister_map_region(map_region: MapRegion) -> void:
	if all_map_regions.has(map_region):
		all_map_regions.erase(map_region)
	if discovered_map_regions.has(map_region):
		discovered_map_regions.erase(map_region)
	if visited_map_regions.has(map_region):
		visited_map_regions.erase(map_region)
	if map_region_grid.has(map_region.map_position) and map_region_grid[map_region.map_position] == map_region:
		map_region_grid.erase(map_region.map_position)
	map_updated.emit()

func discover_map_region(map_region: MapRegion, notify_ui: bool = true) -> void:
	if not discovered_map_regions.has(map_region):
		discovered_map_regions.append(map_region)
		if notify_ui:
			map_updated.emit()

func find_map_region_by_door(target_door: Door) -> MapRegion:
	for map_region in all_map_regions:
		if map_region.is_ancestor_of(target_door):
			return map_region
	return null

func _discover_neighboring_map_regions(map_region: MapRegion) -> void:
	for door in map_region.doors:
		if door.destination_door != null:
			var neighbor_map_region: MapRegion = find_map_region_by_door(door.destination_door)
			if neighbor_map_region != null and not neighbor_map_region.is_secret:
				discover_map_region(neighbor_map_region, false)

func is_transition_active() -> bool:
	return _is_transitioning or TransitionManager.is_transition_active()

## Główna funkcja zmiany pokoju
func change_map_region(new_map_region: MapRegion, target_door: Node2D = null, force_teleport: bool = false) -> void:
	if new_map_region == null:
		push_error("Map: Nie można przejść do pustego pokoju.")
		return
	if is_transition_active():
		return
	_is_transitioning = true

	var player: PlayerCharacter = get_player()
	var old_map_region: MapRegion = current_map_region
	var is_same_map_region: bool = (old_map_region == new_map_region)

	var mode: int = new_map_region.transition_mode if "transition_mode" in new_map_region else 0
	var do_fade: bool = (mode == 0 or mode == 2)
	var do_slide: bool = (mode == 1 or mode == 2)

	if old_map_region == null or is_same_map_region or force_teleport:
		do_slide = false
		do_fade = true

	if player != null:
		player.set_physics_process(false)

	if do_fade:
		TransitionManager.fade_to_black()
		await TransitionManager.on_fade_out_finished
		if not is_inside_tree():
			_finish_transition(player)
			return

	current_map_region = new_map_region

	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	if old_map_region != null and not is_same_map_region:
		old_map_region.process_mode = Node.PROCESS_MODE_DISABLED

	if old_map_region != null and player != null:
		for effect in old_map_region.ambient_aura_effects:
			if effect != null:
				player.remove_effect_by_name(effect.effect_name)

	if player != null and player.get_parent() != null:
		player.get_parent().remove_child(player)

	var slide_vector: Vector2 = Vector2.ZERO
	if do_slide and target_door != null and old_map_region != null and not is_same_map_region:
		if target_door is Door:
			var dir_offset: Vector2i = (target_door as Door).get_direction_offset()
			slide_vector = Vector2(-dir_offset.x * current_map_region.size_px.x, -dir_offset.y * current_map_region.size_px.y)

	# Przygotowujemy chunki nowego pokoju ZANIM wejdzie do drzewa sceny!
	var entry_focus_pos: Vector2 = target_door.position + current_map_region.position if target_door != null else current_map_region.position
	current_map_region.ensure_runtime_initialized(entry_focus_pos)

	current_map_region.position = slide_vector
	current_map_region.visible = true
	if not current_map_region.is_inside_tree():
		add_child(current_map_region)
	if not do_slide:
		_lighting_controller.apply_region(current_map_region)

	if not do_slide and old_map_region != null and not is_same_map_region:
		old_map_region.process_mode = Node.PROCESS_MODE_INHERIT
		_disconnect_door_signals(old_map_region)
		if old_map_region.is_inside_tree():
			remove_child(old_map_region)

	_connect_door_signals(current_map_region)

	discover_map_region(current_map_region, false)
	_discover_neighboring_map_regions(current_map_region)

	if not visited_map_regions.has(current_map_region):
		visited_map_regions.append(current_map_region)

	map_updated.emit()
	map_region_changed.emit(current_map_region)

	if player != null:
		_region_entry_controller.place_player_in_region(
			player,
			current_map_region,
			target_door,
			force_teleport,
			_on_entity_spawn_requested
		)

	current_map_region.check_and_lock_map_region()

	if player != null and "is_in_pacifist_zone" in player:
		player.is_in_pacifist_zone = current_map_region.pacifist_zone

	if do_fade and do_slide:
		TransitionManager.fade_to_normal()
		await TransitionManager.on_fade_in_finished
		if not is_inside_tree():
			return

	if do_slide:
		var tween: Tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

		tween.tween_property(current_map_region, "position", Vector2.ZERO, SLIDE_ANIMATION_DURATION_SEC)
		if old_map_region != null and not is_same_map_region:
			tween.tween_property(old_map_region, "position", -slide_vector, SLIDE_ANIMATION_DURATION_SEC)

		_lighting_controller.add_transition_tweens(
			tween, old_map_region, current_map_region, SLIDE_ANIMATION_DURATION_SEC
		)

		await tween.finished
		if not is_inside_tree():
			_finish_transition(player)
			return

		if old_map_region != null and not is_same_map_region:
			old_map_region.process_mode = Node.PROCESS_MODE_INHERIT
			_disconnect_door_signals(old_map_region)
			if old_map_region.is_inside_tree():
				remove_child(old_map_region)
			old_map_region.position = Vector2.ZERO 
	else:
		if do_fade:
			TransitionManager.fade_to_normal()
			await TransitionManager.on_fade_in_finished
			if not is_inside_tree():
				_finish_transition(player)
				return

	_finish_transition(player)

func _finish_transition(player: PlayerCharacter) -> void:
	_is_transitioning = false
	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_INHERIT
		player.set_physics_process(true)

func _on_entity_spawn_requested(spawned_node: Node2D, spawn_pos: Vector2) -> void:
	if not is_inside_tree() or not is_instance_valid(spawned_node):
		return

	spawned_node.global_position = spawn_pos

	if current_map_region != null:
		var target_parent: Node = current_map_region.find_child("Entities")
		if not target_parent:
			target_parent = current_map_region

		target_parent.call_deferred("add_child", spawned_node)
		spawned_node.set_deferred("global_position", spawn_pos)

		var streamer: Node = current_map_region.get_node_or_null("WorldStreamer")
		if current_map_region.map_region_type == MapRegion.MapRegionType.OPEN_WORLD and streamer != null and streamer.has_method("register_entity"):
			streamer.call_deferred("register_entity", spawned_node)
	else:
		get_tree().current_scene.call_deferred("add_child", spawned_node)
		spawned_node.set_deferred("global_position", spawn_pos)

func _connect_door_signals(map_region: MapRegion) -> void:
	for door in map_region.doors:
		if not door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.connect(_on_door_entered)

func _disconnect_door_signals(map_region: MapRegion) -> void:
	for door in map_region.doors:
		if door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.disconnect(_on_door_entered)

func _on_door_entered(door: Door) -> void:
	if door.destination_door != null:
		var next_map_region: MapRegion = find_map_region_by_door(door.destination_door)
		if next_map_region != null:
			call_deferred("change_map_region", next_map_region, door.destination_door)
		else:
			push_warning("Map: Drzwi docelowe nie znajdują się w żadnym węźle MapRegion!")
	else:
		push_warning("Map: Gracz wszedł w drzwi, ale nie przypisano im destination_door w edytorze.")

func handle_player_respawn(_player: PlayerCharacter) -> void:
	print("Menedżer Mapy: Gracz zainicjował respawn...")

	if starting_map_region != null:
		await change_map_region(starting_map_region, null, true)

		if reset_map_history_on_respawn:
			discovered_map_regions.clear()
			visited_map_regions.clear()
			discover_map_region(starting_map_region, false)
		else:
			discover_map_region(starting_map_region, false)

		map_updated.emit()
	else:
		push_error("Menedżer Mapy: Brak 'starting_map_region'. Twardy reset sceny.")
		get_tree().reload_current_scene()

func get_player() -> PlayerCharacter:
	var tree: SceneTree = get_tree()
	var player: Node = null
	if tree != null:
		player = tree.get_first_node_in_group(PLAYER_GROUP)
	if player == null and GlobalLevelManager.get("stored_player") != null:
		player = GlobalLevelManager.stored_player
	return player as PlayerCharacter

func _exit_tree() -> void:
	var player: PlayerCharacter = get_player()
	if player != null and player.entity_spawn_requested.is_connected(_on_entity_spawn_requested):
		player.entity_spawn_requested.disconnect(_on_entity_spawn_requested)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for map_region in all_map_regions:
			if is_instance_valid(map_region) and map_region.get_parent() == null:
				map_region.queue_free()

func get_map_region_at(coords: Vector2i) -> MapRegion:
	if map_region_grid.has(coords):
		return map_region_grid[coords]
	return null

func _auto_spawn_missing_doors() -> void:
	_door_generator.spawn_missing_doors(map_region_grid)

func _auto_link_doors() -> void:
	_door_generator.link_doors(all_map_regions, map_region_grid)
