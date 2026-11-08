@tool
extends Node2D
## Pokój / Region na mapie poziomu.
class_name MapRegion

const ENEMY_GROUP: String = "Enemy"
const MapRegionSpawnControllerType = preload(
	"res://assets/scripts/map_system/map_region_spawn_controller.gd"
)
## Domyślna scena oświetlenia pokoju załadowana raz do pamięci podręcznej (brak lagów przy load()).
const DEFAULT_LIGHT_SCENE: PackedScene = preload(
	"res://assets/scenes/map_system/map_regions/map_region_light.tscn"
)

const MIN_ROOM_TILES_DIMENSION: int = 3
const DEBUG_RECT_COLOR := Color(0.0, 1.0, 0.0, 0.2)
const DEBUG_RECT_WIDTH: float = 2.0

var _spawn_controller: MapRegionSpawnControllerType = MapRegionSpawnControllerType.new()
var _runtime_streamer_initialized: bool = false
var _hierarchy_scanned: bool = false

@export_group("Mapa")
## Pozycja pokoju na siatce minimapy (np. 0,0 to start, 1,0 to pokój po prawej)
@export var map_position : Vector2i = Vector2i.ZERO
## Czy ten pokój ma zostać narysowany na minimapie?
@export var is_mappable : bool = false

enum TransitionMode { FADE, SLIDE, BOTH }

@export_group("Ustawienia Przejścia")
## Definiuje, w jaki sposób kamera i ekran zachowają się przy wchodzeniu do TEGO pokoju.
@export var transition_mode: TransitionMode = TransitionMode.FADE

@export_group("Typ i Znaczenie Pokoju")
enum MapRegionType { NORMAL, START, TREASURE, SHOP, BOSS, OPEN_WORLD, DEV_ROOM, ARENA }

## Określa typ pokoju. Przydatne dla Minimapy (ikony), Menedżera Muzyki oraz logiki gry.
@export var map_region_type: MapRegionType = MapRegionType.NORMAL

## Jeśli prawda, pokój pojawi się na mapie dopiero po wejściu do niego
@export var is_secret : bool = false

@export_group("Logika Walki i Ograniczenia")
## Strefa Bezpieczna: pokój NIGDY nie zablokuje drzwi (idealne dla Sklepów i Dev MapRegiona).
@export var ignore_combat_lock: bool = false
## Klatka (One-Way): Gdy gracz wejdzie do pokoju, drzwi się zamkną i NIE otworzą nawet po zabiciu wrogów. (Pokoje Bossa, pułapki).
@export var lock_permanently_after_entry: bool = false
## Pacyfizm: Jeśli włączone, gracz ma zablokowaną możliwość używania broni i rzucania itemami (Sklepy, NPC).
@export var pacifist_zone: bool = false

@export_group("Oświetlenie Pokoju (Live Preview)")
## Jeśli włączone, pokój nakłada na siebie Mroczną Maskę.
@export var is_dark_map_region: bool = false:
	set(value):
		is_dark_map_region = value
		_update_lighting()

## Kolor mroku (domyślnie bardzo ciemny szary).
@export var darkness_color: Color = Color(0.09, 0.09, 0.09, 1.0):
	set(value):
		darkness_color = value
		_update_lighting()

## Jeśli włączone, gra automatycznie wstawi światło na idealnym środku pokoju.
@export var has_center_light: bool = false:
	set(value):
		has_center_light = value
		_update_lighting()

## Przeciągnij tutaj swoją scenę światła (np. map_region_light.tscn)
@export var light_scene: PackedScene:
	set(value):
		light_scene = value
		_update_lighting()

## Moc/Jasność (Energy) wygenerowanego światła.
@export_range(0.0, 5.0) var center_light_energy: float = 1.2:
	set(value):
		center_light_energy = value
		_update_lighting()

## Skala (zasięg) wygenerowanego światła.
@export_range(0.1, 10.0) var center_light_scale: float = 1.5:
	set(value):
		center_light_scale = value
		_update_lighting()

@export_group("Efekty Środowiskowe (Hazards)")
## AURA (Znika po wyjściu): Efekty aktywne TYLKO w tym pokoju (np. Spowolnienie od błota). Trwają w nieskończoność, dopóki gracz tu jest.
@export var ambient_aura_effects: Array[Effect] = []
## KLĄTWA (Zostaje po wyjściu): Efekty nakładane przy wejściu. Mają swój standardowy czas trwania i znikną same, nawet po zmianie pokoju.
@export var sticky_entry_effects: Array[Effect] = []

@export_group("Kamera")
## Jeśli true: Kamera płynnie podąża za graczem, nie wychodząc poza ściany pokoju.
## Jeśli false: Kamera na sztywno blokuje się na środku pokoju (styl The Binding of Isaac).
@export var camera_follows_player: bool = false

@export_group("Generatory Proceduralne (Spawn Pools)")
## Pula przeciwników (Losowana na markerach z grupy 'EnemySpawn')
@export var enemy_pool: EnemySpawnPool
@export_range(0.0, 1.0) var enemy_spawn_chance: float = 1.0

@export var object_pool: ObjectSpawnPool
@export_range(0.0, 1.0) var object_spawn_chance: float = 1.0

@export var item_pool: ItemLootPool
@export_range(0.0, 1.0) var item_spawn_chance: float = 1.0

var enemy_spawns: Array[Marker2D] = []
var object_spawns: Array[Marker2D] = []
var item_spawns: Array[Marker2D] = []
var advanced_spawners: Array[Node] = []
var level_entrances: Array[LevelEntrance] = []
var hybrid_storage_containers: Array[Node] = []
var has_spawned_entities: bool = false

@export_group("Wymiary Pokoju")
@export var map_region_size_tiles : Vector2i = Vector2i(30, 17):
	set(value):
		value.x = maxi(MIN_ROOM_TILES_DIMENSION, value.x)
		value.y = maxi(MIN_ROOM_TILES_DIMENSION, value.y)
		map_region_size_tiles = value
		if Engine.is_editor_hint() or is_inside_tree():
			generate_map_region()
			queue_redraw()

@export_group("Ustawienia Generowania")
## Jeśli włączone, skrypt NIE wyczyści i NIE nadpisze Twojej TileMapy. 
@export var manual_tilemap_override: bool = false:
	set(value):
		manual_tilemap_override = value
		if Engine.is_editor_hint() or is_inside_tree():
			generate_map_region()
			queue_redraw()

@export var tile_source_id : int = 0

@export_subgroup("Podłoga")
@export var floor_atlas_pos : Vector2i = Vector2i(0, 0)
@export var floor_alt_id : int = 0:
	set(value):
		floor_alt_id = maxi(0, value)
		if Engine.is_editor_hint() or is_inside_tree():
			generate_map_region()

@export_subgroup("Ściana")
@export var wall_atlas_pos : Vector2i = Vector2i(1, 0)
@export var wall_alt_id : int = 0:
	set(value):
		wall_alt_id = maxi(0, value)
		if Engine.is_editor_hint() or is_inside_tree():
			generate_map_region()

@export_group("Drzwi")
## Jeśli wrzucisz tu teksturę, drzwi PROWADZĄCE DO TEGO POKOJU oraz DRZWI W TYM POKOJU przyjmą ten wygląd.
@export var custom_door_texture: Texture2D
var doors : Array[Door] = []

signal map_region_cleared 
var active_enemies_count : int = 0

@export_group("Auto-Drzwi (Przejścia)")
## Decyduje, czy ten pokój zezwala na wygenerowanie drzwi na danej ścianie.
@export var allow_door_up: bool = true
@export var allow_door_down: bool = true
@export var allow_door_left: bool = true
@export var allow_door_right: bool = true

@export_group("Elementy Pokoju")
@onready var floor_tile_map : TileMapLayer = $FloorTileMap
@onready var navigation_region_2d : NavigationRegion2D = $NavigationRegion2D
@export var spawn_points : Array[Marker2D] = []

var size_px : Vector2

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	if map_region_type == MapRegionType.OPEN_WORLD and not _runtime_streamer_initialized:
		ensure_runtime_initialized()

func _ready() -> void:
	if floor_tile_map == null:
		floor_tile_map = get_node_or_null("FloorTileMap") as TileMapLayer
	if navigation_region_2d == null:
		navigation_region_2d = get_node_or_null("NavigationRegion2D") as NavigationRegion2D

	if floor_tile_map != null:
		floor_tile_map.z_index = GameLayers.FLOOR

	if map_region_type == MapRegionType.OPEN_WORLD:
		camera_follows_player = true
		ignore_combat_lock = true

	generate_map_region()
	_update_lighting()

	if not Engine.is_editor_hint() and not _hierarchy_scanned:
		_scan_region_hierarchy_once()

## Asynchronicznie przygotowuje pokój przed wejściem do SceneTree (porcjuje tysiące węzłów z budżetem 6 ms).
func prepare_region_before_tree_async(
	is_active_start_region: bool,
	tree: SceneTree,
	initial_focus_pos: Vector2 = Vector2.INF
) -> void:
	if floor_tile_map == null:
		floor_tile_map = get_node_or_null("FloorTileMap") as TileMapLayer
	if navigation_region_2d == null:
		navigation_region_2d = get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	calculate_map_region_bounds()
	if not _hierarchy_scanned:
		_scan_region_hierarchy_once()
	if is_active_start_region and map_region_type == MapRegionType.OPEN_WORLD:
		await ensure_runtime_initialized_async(tree, initial_focus_pos, true)

func prepare_region_before_tree(is_active_start_region: bool, initial_focus_pos: Vector2 = Vector2.INF) -> void:
	if floor_tile_map == null:
		floor_tile_map = get_node_or_null("FloorTileMap") as TileMapLayer
	if navigation_region_2d == null:
		navigation_region_2d = get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	calculate_map_region_bounds()
	if not _hierarchy_scanned:
		_scan_region_hierarchy_once()
	if is_active_start_region and map_region_type == MapRegionType.OPEN_WORLD:
		ensure_runtime_initialized(initial_focus_pos)

func ensure_runtime_initialized_async(
	tree: SceneTree,
	initial_focus_pos: Vector2 = Vector2.INF,
	defer_chunk_activation: bool = false
) -> void:
	if Engine.is_editor_hint():
		return
	if map_region_type == MapRegionType.OPEN_WORLD:
		var streamer: WorldStreamer = get_node_or_null("WorldStreamer") as WorldStreamer
		if not _runtime_streamer_initialized or streamer == null:
			_runtime_streamer_initialized = true
			if streamer == null:
				streamer = WorldStreamer.new()
				streamer.name = "WorldStreamer"
				streamer.chunk_size = GlobalSettings.chunk_base_size
				add_child(streamer)
			var entities_node: Node = find_child("Entities")
			var target_container: Node = entities_node if entities_node != null else self
			await streamer.initialize_async(target_container, tree, initial_focus_pos, defer_chunk_activation)
			print("WorldStreamer zainicjowany w pokoju otwartym: ", name)
		elif not defer_chunk_activation:
			await streamer.activate_chunks_async(tree, initial_focus_pos)

func ensure_runtime_initialized(initial_focus_pos: Vector2 = Vector2.INF) -> void:
	if Engine.is_editor_hint():
		return
	if map_region_type == MapRegionType.OPEN_WORLD:
		if not _runtime_streamer_initialized:
			_runtime_streamer_initialized = true
			_setup_world_streamer(initial_focus_pos)
		elif initial_focus_pos != Vector2.INF:
			var existing_streamer: WorldStreamer = get_node_or_null("WorldStreamer") as WorldStreamer
			if existing_streamer != null:
				existing_streamer.refresh_focus_position(initial_focus_pos)

func _setup_world_streamer(initial_focus_pos: Vector2 = Vector2.INF) -> void:
	var streamer: WorldStreamer = get_node_or_null("WorldStreamer") as WorldStreamer
	if streamer == null:
		streamer = WorldStreamer.new()
		streamer.name = "WorldStreamer"
		streamer.chunk_size = GlobalSettings.chunk_base_size
		add_child(streamer)

	var entities_node: Node = find_child("Entities")
	if entities_node != null:
		streamer.initialize(entities_node, initial_focus_pos)
	else:
		streamer.initialize(self, initial_focus_pos)

	print("WorldStreamer zainicjowany w pokoju otwartym: ", name)

## Pojedyncze, zoptymalizowane przejście po hierarchii pokoju (zamiast 7 osobnych rekurencji!).
func _scan_region_hierarchy_once() -> void:
	_hierarchy_scanned = true
	doors.clear()
	spawn_points.clear()
	enemy_spawns.clear()
	object_spawns.clear()
	item_spawns.clear()
	advanced_spawners.clear()
	level_entrances.clear()
	hybrid_storage_containers.clear()
	_scan_node_recursive(self)

func _scan_node_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Door:
			doors.append(child as Door)
		elif child is LevelEntrance:
			level_entrances.append(child as LevelEntrance)
		elif child is Marker2D:
			var marker: Marker2D = child as Marker2D
			if marker is BaseWorldSpawner or marker.is_in_group("AdvancedSpawner"):
				advanced_spawners.append(marker)
			elif marker.is_in_group("EnemySpawn"):
				enemy_spawns.append(marker)
			elif marker.is_in_group("ObjectSpawn"):
				object_spawns.append(marker)
			elif marker.is_in_group("ItemSpawn"):
				item_spawns.append(marker)
			elif marker.is_in_group("RespawnPoint"):
				spawn_points.append(marker)

		if child.get_node_or_null("StorageComponent") != null:
			hybrid_storage_containers.append(child)

		if child is CharacterEntity or child is ItemPickup or child is PlacedObject:
			continue

		if child.get_child_count() > 0:
			_scan_node_recursive(child)

## Generowanie pokoju (Proceduralne LUB Ręczne)
func generate_map_region() -> void:
	if floor_tile_map == null:
		floor_tile_map = get_node_or_null("FloorTileMap") as TileMapLayer
	if not floor_tile_map:
		return

	# OPTYMALIZACJA O(1): Używamy get_used_rect().size == Vector2i.ZERO zamiast get_used_cells().is_empty(),
	# ponieważ get_used_cells() na wielkiej mapie alokuje gigantyczną tablicę wszystkich kafelków!
	var should_rebuild_cells: bool = not manual_tilemap_override and (
		Engine.is_editor_hint() or floor_tile_map.get_used_rect().size == Vector2i.ZERO
	)
	if should_rebuild_cells:
		floor_tile_map.clear()
		for x in range(map_region_size_tiles.x):
			for y in range(map_region_size_tiles.y):
				var current_pos: Vector2i = Vector2i(x, y)
				if x == 0 or x == map_region_size_tiles.x - 1 or y == 0 or y == map_region_size_tiles.y - 1:
					floor_tile_map.set_cell(current_pos, tile_source_id, wall_atlas_pos, wall_alt_id)
				else:
					floor_tile_map.set_cell(current_pos, tile_source_id, floor_atlas_pos, floor_alt_id)

	calculate_map_region_bounds()
	if Engine.is_editor_hint() or navigation_region_2d == null or navigation_region_2d.navigation_polygon == null:
		update_navigation_region()
	_update_lighting()

func get_door(dir: Door.Direction) -> Door:
	for d in doors:
		if d.door_direction == dir:
			return d
	return null

func spawn_auto_door(dir: Door.Direction, door_scene: PackedScene, custom_tex: Texture2D = null) -> Door:
	var existing_door: Door = get_door(dir)
	if existing_door != null:
		return existing_door

	if not floor_tile_map or not floor_tile_map.tile_set:
		return null

	var tile_size: Vector2i = floor_tile_map.tile_set.tile_size
	var map_region_width_px: float = float(map_region_size_tiles.x * tile_size.x)
	var map_region_height_px: float = float(map_region_size_tiles.y * tile_size.y)

	var exact_pos: Vector2 = Vector2.ZERO
	match dir:
		Door.Direction.UP:
			exact_pos = Vector2(map_region_width_px / 2.0, float(tile_size.y) / 2.0)
		Door.Direction.DOWN:
			exact_pos = Vector2(map_region_width_px / 2.0, map_region_height_px - (float(tile_size.y) / 2.0))
		Door.Direction.LEFT:
			exact_pos = Vector2(float(tile_size.x) / 2.0, map_region_height_px / 2.0)
		Door.Direction.RIGHT:
			exact_pos = Vector2(map_region_width_px - (float(tile_size.x) / 2.0), map_region_height_px / 2.0)

	var new_door: Door = door_scene.instantiate() as Door
	new_door.door_direction = dir

	match dir:
		Door.Direction.UP: new_door.rotation_degrees = 0.0
		Door.Direction.DOWN: new_door.rotation_degrees = 180.0
		Door.Direction.LEFT: new_door.rotation_degrees = -90.0
		Door.Direction.RIGHT: new_door.rotation_degrees = 90.0

	new_door.position = exact_pos

	if custom_tex != null:
		new_door.door_texture = custom_tex

	add_child(new_door)
	doors.append(new_door)
	return new_door

func update_navigation_region() -> void:
	if navigation_region_2d == null:
		navigation_region_2d = get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	if not navigation_region_2d or not floor_tile_map or not floor_tile_map.tile_set:
		return

	var tile_size: Vector2i = floor_tile_map.tile_set.tile_size
	var nav_poly: NavigationPolygon = NavigationPolygon.new()
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(float(map_region_size_tiles.x * tile_size.x), 0.0),
		Vector2(float(map_region_size_tiles.x * tile_size.x), float(map_region_size_tiles.y * tile_size.y)),
		Vector2(0.0, float(map_region_size_tiles.y * tile_size.y))
	])

	nav_poly.vertices = points
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	navigation_region_2d.navigation_polygon = nav_poly

func calculate_map_region_bounds() -> void:
	if floor_tile_map == null:
		floor_tile_map = get_node_or_null("FloorTileMap") as TileMapLayer
	if floor_tile_map and floor_tile_map.tile_set:
		var tile_size: Vector2i = floor_tile_map.tile_set.tile_size
		size_px = Vector2(float(map_region_size_tiles.x * tile_size.x), float(map_region_size_tiles.y * tile_size.y))

func _draw() -> void:
	if Engine.is_editor_hint() or OS.is_debug_build():
		if is_instance_valid(floor_tile_map) and floor_tile_map.tile_set:
			var tile_size: Vector2i = floor_tile_map.tile_set.tile_size
			var rect: Rect2 = Rect2(
				Vector2.ZERO,
				Vector2(float(map_region_size_tiles.x * tile_size.x), float(map_region_size_tiles.y * tile_size.y))
			)
			draw_rect(rect, DEBUG_RECT_COLOR, false, DEBUG_RECT_WIDTH)

func _update_lighting() -> void:
	if not is_inside_tree():
		return

	var mod_name: String = "MapRegionDarkness"
	var darkness: CanvasModulate = find_child(mod_name, false, false) as CanvasModulate

	if Engine.is_editor_hint() and is_dark_map_region:
		if not darkness:
			darkness = CanvasModulate.new()
			darkness.name = mod_name
			add_child(darkness)
		darkness.color = darkness_color
	else:
		if darkness:
			darkness.queue_free()

	var light_name: String = "CenterMapRegionLight"
	var light: Node = find_child(light_name, false, false)

	if has_center_light:
		if not light:
			var scene_to_load: PackedScene = light_scene if light_scene != null else DEFAULT_LIGHT_SCENE
			if scene_to_load != null:
				light = scene_to_load.instantiate()
				light.name = light_name
				add_child(light)

		calculate_map_region_bounds()
		if light is Node2D:
			(light as Node2D).position = size_px / 2.0

		if light is PointLight2D:
			var point_light: PointLight2D = light as PointLight2D
			point_light.energy = center_light_energy
			if point_light.texture != null:
				var tex_size: Vector2 = point_light.texture.get_size()
				var scale_x: float = size_px.x / maxf(1.0, tex_size.x)
				var scale_y: float = size_px.y / maxf(1.0, tex_size.y)
				point_light.texture_scale = maxf(scale_x, scale_y) * center_light_scale
			else:
				point_light.texture_scale = center_light_scale
	else:
		if light:
			light.queue_free()

#region Logika stanu walki
## Asynchroniczna wersja aktywacji pokoju (używana podczas ekranu ładowania ogromnych map).
func check_and_lock_map_region_async(tree: SceneTree, focus_pos: Vector2 = Vector2.INF) -> void:
	await ensure_runtime_initialized_async(tree, focus_pos, false)

	if not has_spawned_entities and not pacifist_zone:
		await _spawn_controller.spawn_region_async(self, tree)
		has_spawned_entities = true

	_apply_combat_door_locks()

## Synchroniczna wersja sprawdzania walki i blokowania drzwi.
func check_and_lock_map_region() -> void:
	ensure_runtime_initialized()

	if not has_spawned_entities and not pacifist_zone:
		_spawn_controller.spawn_region(self)
		has_spawned_entities = true

	_apply_combat_door_locks()

func _apply_combat_door_locks() -> void:
	if ignore_combat_lock:
		for door in doors:
			door.unlock_combat_door()
		return

	if lock_permanently_after_entry:
		print("Pułapka! Zamykam drzwi na stałe w pokoju: " + name)
		for door in doors:
			door.combat_lock_door()
		return

	active_enemies_count = 0
	_find_enemies_recursive(self)

	if active_enemies_count > 0:
		for door in doors:
			door.combat_lock_door()
	else:
		for door in doors:
			door.unlock_combat_door()

func _find_enemies_recursive(node: Node) -> void:
	for child in node.get_children():
		if child.is_in_group(ENEMY_GROUP):
			active_enemies_count += 1

			var has_health_script: bool = child.get("health_stats_script") != null
			if has_health_script:
				if not child.health_stats_script.died.is_connected(_on_enemy_died):
					child.health_stats_script.died.connect(_on_enemy_died)
			else:
				if not child.tree_exited.is_connected(_on_enemy_died):
					child.tree_exited.connect(_on_enemy_died.bind(child))

		if child is CharacterEntity or child is ItemPickup or child is PlacedObject:
			continue
		if child.get_child_count() > 0:
			_find_enemies_recursive(child)

func _on_enemy_died(enemy: Node = null) -> void:
	if enemy != null and not enemy.is_queued_for_deletion():
		return

	active_enemies_count -= 1
	if active_enemies_count <= 0:
		map_region_cleared.emit()
		if lock_permanently_after_entry:
			print("Pokój oczyszczony, ale to pułapka! Drzwi pozostają zamknięte.")
		else:
			print("Pokój oczyszczony! Odblokowuję drzwi.")
			for door in doors:
				door.unlock_combat_door()
#endregion
