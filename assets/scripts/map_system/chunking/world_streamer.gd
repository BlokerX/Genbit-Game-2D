extends Node2D
class_name WorldStreamer

# --- STAŁE DOMENOWE I DEBUGOWANIA (Brak magicznych liczb) ---
const UNINITIALIZED_CHUNK_COORD: int = 999999
const DEBUG_BORDER_WIDTH: float = 8.0
const DEBUG_FONT_SIZE: int = 64
const DEBUG_TEXT_SHADOW_OFFSET := Vector2(24.0, 84.0)
const DEBUG_TEXT_MAIN_OFFSET := Vector2(20.0, 80.0)
const DEBUG_BORDER_COLOR := Color(0.2, 1.0, 0.4, 0.6)
const DEBUG_FILL_COLOR := Color(0.2, 1.0, 0.4, 0.05)
const DEBUG_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.8)

@export_group("Konfiguracja Streamingu")
## Rozmiar jednego chunka w pikselach (domyślnie nadpisywany przez MapRegion z GlobalSettings)
@export var chunk_size: int = 2048

var current_chunk: Vector2i = Vector2i(UNINITIALIZED_CHUNK_COORD, UNINITIALIZED_CHUNK_COORD)
var active_chunks: Array[Vector2i] = []
var player: Node2D
var chunk_nodes: Dictionary = {}
var entities_container: Node

# Wewnętrzna zmienna trzymająca poziom renderowania zaczytany z ustawień gry
var _current_render_level: int = 1  
var _last_grid_state: bool = false
var _is_initialized: bool = false

# --- BAZA KSZTAŁTÓW RENDEROWANIA ---
# Typy: "SQUARE" (Kwadrat), "DIAMOND" (Romb / Krzyż), "CIRCLE" (Koło)
const RENDER_PROFILES = [
	{"shape": "SQUARE", "radius": 0},  # Poziom 1: 1 chunk (Tylko gracz)
	{"shape": "DIAMOND", "radius": 1}, # Poziom 2: 5 chunków (Krzyż)
	{"shape": "SQUARE", "radius": 1},  # Poziom 3: 9 chunków (Kwadrat 3x3)
	{"shape": "DIAMOND", "radius": 2}, # Poziom 4: 13 chunków (Diament)
	{"shape": "CIRCLE", "radius": 2},  # Poziom 5: 21 chunków (Koło bez rogów)
	{"shape": "SQUARE", "radius": 2},  # Poziom 6: 25 chunków (Kwadrat 5x5)
	{"shape": "CIRCLE", "radius": 3},  # Poziom 7: 37 chunków (Większe koło)
	{"shape": "SQUARE", "radius": 3},  # Poziom 8: 49 chunków (Kwadrat 7x7)
	{"shape": "CIRCLE", "radius": 4},  # Poziom 9: 69 chunków (Duże koło)
	{"shape": "SQUARE", "radius": 4},  # Poziom 10: 81 chunków (Kwadrat 9x9)
	{"shape": "CIRCLE", "radius": 6},  # Poziom 11: 145 chunków (Ogromne koło)
	{"shape": "SQUARE", "radius": 7}   # Poziom 12: 225 chunków (Kwadrat 15x15)
]

func _ready() -> void:
	# Rejestracja w grupie pozwala spawnerom znaleźć WorldStreamer w czasie O(1) bez find_child()!
	add_to_group("WorldStreamer")

## Inicjalizuje streamer i natychmiast segreguje obiekty na chunki.
## Może zostać wywołana ZANIM mapa wejdzie do drzewa sceny (initial_focus_pos),
## dzięki czemu tysiące botów w dalekich chunkach w ogóle nie uruchomią swojego _ready() na starcie!
func initialize(container: Node, initial_focus_pos: Vector2 = Vector2.INF) -> void:
	if _is_initialized and entities_container == container:
		if initial_focus_pos != Vector2.INF:
			refresh_focus_position(initial_focus_pos)
		return

	entities_container = container
	if chunk_size <= 0:
		chunk_size = GlobalSettings.chunk_base_size

	_current_render_level = GlobalSettings.chunk_render_distance
	_last_grid_state = GlobalSettings.show_chunk_grid

	# 1. USTALENIE PUNKTU CENTRALNEGO (z przekazanego spawnu lub z pozycji gracza)
	var focus_pos: Vector2 = initial_focus_pos
	if focus_pos == Vector2.INF and is_inside_tree():
		player = get_tree().get_first_node_in_group("Player") as Node2D
		if is_instance_valid(player):
			focus_pos = player.global_position
	if focus_pos == Vector2.INF:
		focus_pos = Vector2.ZERO

	current_chunk = _calculate_chunk(focus_pos)

	# 2. GŁĘBOKIE SKANOWANIE MAPY (Spłaszczanie struktury folderów przed wejściem do drzewa!)
	var entities_to_register: Array[Node] = []
	_gather_streamables(entities_container, entities_to_register)

	for entity in entities_to_register:
		register_entity(entity)

	# 3. NATYCHMIASTOWE WYMUSZENIE AKTUALIZACJI CHUNKÓW
	# Zanim silnik narysuje pierwszą klatkę (i zanim dalekie boty wejdą do SceneTree!),
	# w drzewie zostają wyłącznie chunki wokół punktu startowego gracza.
	_update_active_chunks()

	_is_initialized = true
	set_process(true)
	if is_inside_tree() and GlobalSettings.show_chunk_grid:
		queue_redraw()
	print("[WorldStreamer] Zbudowano fizyczną siatkę chunków. Aktywna hibernacja obiektów.")

## Wymusza przeliczenie aktywnych chunków dla nowej pozycji gracza (np. po teleportacji na portal).
func refresh_focus_position(focus_pos: Vector2) -> void:
	var new_chunk: Vector2i = _calculate_chunk(focus_pos)
	if new_chunk != current_chunk or active_chunks.is_empty():
		current_chunk = new_chunk
		_update_active_chunks()

## Zamraża i odpina z drzewa absolutnie wszystkie chunki (używane, gdy mapa trafia do schowka RAM).
## Odciąża serwer fizyki, nawigacji i renderowania z nieaktywnych poziomów.
func hibernate_all_chunks() -> void:
	if not is_instance_valid(entities_container):
		return
	for coords in active_chunks:
		var chunk_node: Node2D = chunk_nodes.get(coords)
		if is_instance_valid(chunk_node) and chunk_node.is_inside_tree():
			for child in chunk_node.get_children():
				if child is RigidBody2D:
					(child as RigidBody2D).freeze = true
			entities_container.remove_child(chunk_node)
	active_chunks.clear()
	set_process(false)

## Przywraca aktywne chunki po wyciągnięciu mapy ze schowka RAM.
func restore_active_chunks(focus_pos: Vector2) -> void:
	set_process(true)
	current_chunk = _calculate_chunk(focus_pos)
	_update_active_chunks()

## Funkcja głęboko skanująca drzewo. Wyciąga obiekty z pustych folderów Node2D.
func _gather_streamables(node: Node, result: Array[Node]) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child.name.begins_with("Chunk_") or child.name == "WorldStreamer":
			continue
		if child is TileMapLayer or child is NavigationRegion2D or child is CanvasModulate or child is Camera2D:
			continue
		if child.is_in_group("Player") or child.is_in_group("AlwaysActive"):
			continue
		if not child is Node2D:
			continue

		# ROZPOZNAWANIE OBIEKTU: Definiujemy, co ma trafić do zamrażarki chunków
		var is_entity: bool = false
		if child is BaseWorldSpawner or child.is_in_group("AdvancedSpawner"):
			is_entity = true
		elif (
			child is CollisionObject2D
			or child.is_in_group("Enemy")
			or child.is_in_group("ItemPickup")
			or child.is_in_group("PlacedObject")
			or child.is_in_group("Hazard")
		):
			is_entity = true

		if is_entity:
			result.append(child)
		else:
			# Jeśli to zwykły "pusty folder" Node2D lub stary Marker2D, schodzimy warstwę głębiej!
			_gather_streamables(child, result)

# --- PRZEŁĄCZANIE W LOCIE (INPUT MAP) ---
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ToggleChunkGrid"):
		GlobalSettings.show_chunk_grid = not GlobalSettings.show_chunk_grid
		queue_redraw()
		print("WorldStreamer: Widok siatki chunków = ", GlobalSettings.show_chunk_grid)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player") as Node2D
		return

	_track_moving_entities()

	# --- NASŁUCHIWANIE ZMIAN Z MENU OPCJI ---
	var target_level: int = GlobalSettings.chunk_render_distance
	var level_changed: bool = false
	if _current_render_level != target_level:
		_current_render_level = target_level
		level_changed = true

	var new_chunk: Vector2i = _calculate_chunk(player.global_position)
	if new_chunk != current_chunk or level_changed:
		current_chunk = new_chunk
		_update_active_chunks()

	if GlobalSettings.show_chunk_grid != _last_grid_state:
		_last_grid_state = GlobalSettings.show_chunk_grid
		queue_redraw()

func register_entity(node: Node) -> void:
	if not is_instance_valid(node) or not node is Node2D:
		return
	if node.is_in_group("Player") or node.is_in_group("AlwaysActive"):
		return

	# Streamer ignoruje zwykłe pomocnicze Marker2D (np. RespawnPoint),
	# ALE wpuszcza wszystkie zaawansowane spawnery (EntitySpawner, LootSpawner, ObjectSpawner)!
	if node is Marker2D and not (node is BaseWorldSpawner or node.is_in_group("AdvancedSpawner")):
		return

	if node is TileMapLayer or node is NavigationRegion2D or node is CanvasModulate or node is Camera2D:
		return
	if node.name.begins_with("Chunk_") or node.name == "WorldStreamer":
		return

	var node_2d: Node2D = node as Node2D
	var world_pos: Vector2 = _get_node_world_position(node_2d)
	var chunk_coords: Vector2i = _calculate_chunk(world_pos)
	var chunk_node: Node2D = _get_or_create_chunk(chunk_coords)

	_transfer_node_to_chunk(node_2d, chunk_node)

## Oblicza pozycję węzła 2D w świecie – działa poprawnie zarówno gdy węzeł jest w drzewie sceny,
## jak i wtedy, gdy mapa jest dopiero przygotowywana w pamięci RAM przed add_child()!
func _get_node_world_position(node_2d: Node2D) -> Vector2:
	if node_2d.is_inside_tree():
		return node_2d.global_position
	var accum_transform: Transform2D = _get_transform_relative_to_root(node_2d)
	return accum_transform.origin

func _get_transform_relative_to_root(node_2d: Node2D) -> Transform2D:
	var xform: Transform2D = node_2d.transform
	var curr: Node = node_2d.get_parent()
	while curr != null and curr != entities_container:
		if curr is Node2D:
			xform = (curr as Node2D).transform * xform
		curr = curr.get_parent()
	return xform

## Bezpiecznie przenosi węzeł 2D do docelowego chunka, zachowując jego transformację (w drzewie i poza nim).
func _transfer_node_to_chunk(node_2d: Node2D, target_chunk_node: Node2D) -> void:
	if not is_instance_valid(node_2d) or not is_instance_valid(target_chunk_node):
		return
	if node_2d.get_parent() == target_chunk_node:
		return

	var preserved_transform: Transform2D = (
		node_2d.global_transform
		if node_2d.is_inside_tree()
		else _get_transform_relative_to_root(node_2d)
	)
	var was_in_tree: bool = node_2d.is_inside_tree()

	var current_parent: Node = node_2d.get_parent()
	if current_parent != null:
		current_parent.remove_child(node_2d)

	target_chunk_node.add_child(node_2d)
	if was_in_tree and target_chunk_node.is_inside_tree():
		node_2d.global_transform = preserved_transform
	else:
		node_2d.transform = preserved_transform

	# Jeśli docelowy chunk jest uśpiony poza drzewem, zamrażamy fizykę RigidBody2D
	if not target_chunk_node.is_inside_tree() and node_2d is RigidBody2D:
		(node_2d as RigidBody2D).freeze = true
	elif target_chunk_node.is_inside_tree() and node_2d is RigidBody2D:
		(node_2d as RigidBody2D).freeze = false

func _track_moving_entities() -> void:
	for coords in active_chunks:
		if not chunk_nodes.has(coords):
			continue
		var chunk_node: Node2D = chunk_nodes[coords]
		if not is_instance_valid(chunk_node):
			continue

		var children_snapshot: Array[Node] = chunk_node.get_children()
		for entity in children_snapshot:
			if not is_instance_valid(entity) or entity.is_queued_for_deletion() or not entity is Node2D:
				continue
			if entity is BaseWorldSpawner:
				continue

			var entity_2d: Node2D = entity as Node2D
			var actual_coords: Vector2i = _calculate_chunk(entity_2d.global_position)

			if actual_coords != coords:
				var new_chunk_node: Node2D = _get_or_create_chunk(actual_coords)
				_transfer_node_to_chunk(entity_2d, new_chunk_node)

func _calculate_chunk(pos: Vector2) -> Vector2i:
	var safe_size: float = float(maxi(1, chunk_size))
	return Vector2i(int(floor(pos.x / safe_size)), int(floor(pos.y / safe_size)))

func _get_or_create_chunk(coords: Vector2i) -> Node2D:
	if chunk_nodes.has(coords):
		return chunk_nodes[coords]

	var new_chunk: Node2D = Node2D.new()
	new_chunk.name = "Chunk_" + str(coords.x) + "_" + str(coords.y)
	chunk_nodes[coords] = new_chunk
	return new_chunk

## Oblicza wektory chunków wokół gracza na podstawie wybranego kształtu renderowania.
func _get_offsets_for_current_level() -> Array[Vector2i]:
	var safe_level: int = clampi(_current_render_level - 1, 0, RENDER_PROFILES.size() - 1)
	var profile: Dictionary = RENDER_PROFILES[safe_level]

	var shape: String = profile["shape"]
	var r: int = profile["radius"]
	var offsets: Array[Vector2i] = []

	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			if shape == "SQUARE":
				offsets.append(Vector2i(x, y))
			elif shape == "DIAMOND":
				if abs(x) + abs(y) <= r:
					offsets.append(Vector2i(x, y))
			elif shape == "CIRCLE":
				if (x * x + y * y) <= (r * r) + r:
					offsets.append(Vector2i(x, y))

	return offsets

func _update_active_chunks() -> void:
	if not is_instance_valid(entities_container):
		return

	var new_active_chunks: Array[Vector2i] = []
	var offsets: Array[Vector2i] = _get_offsets_for_current_level()

	for offset in offsets:
		new_active_chunks.append(current_chunk + offset)

	# 1. ZAMRAŻANIE (Odpinanie dalekich chunków z drzewa sceny)
	for coords in active_chunks:
		if not new_active_chunks.has(coords):
			var chunk_node: Node2D = chunk_nodes.get(coords)
			if is_instance_valid(chunk_node) and chunk_node.get_parent() == entities_container:
				for child in chunk_node.get_children():
					if child is RigidBody2D:
						(child as RigidBody2D).freeze = true
				entities_container.remove_child(chunk_node)

	# 2. OŻYWIANIE (Podpinanie pobliskich chunków do kontenera Entities)
	for coords in new_active_chunks:
		if not active_chunks.has(coords):
			var chunk_node: Node2D = _get_or_create_chunk(coords)
			if chunk_node.get_parent() != entities_container:
				entities_container.add_child(chunk_node)
				for child in chunk_node.get_children():
					if child is RigidBody2D:
						(child as RigidBody2D).freeze = false

	active_chunks = new_active_chunks
	if is_inside_tree() and GlobalSettings.show_chunk_grid:
		queue_redraw()

func _draw() -> void:
	if not GlobalSettings.show_chunk_grid:
		return

	var font: Font = ThemeDB.fallback_font
	for chunk in active_chunks:
		var chunk_pos: Vector2 = Vector2(chunk.x * chunk_size, chunk.y * chunk_size)
		var rect: Rect2 = Rect2(chunk_pos, Vector2(chunk_size, chunk_size))

		draw_rect(rect, DEBUG_BORDER_COLOR, false, DEBUG_BORDER_WIDTH)
		draw_rect(rect, DEBUG_FILL_COLOR, true)

		if font != null:
			var text: String = "CHUNK [" + str(chunk.x) + ", " + str(chunk.y) + "]"
			draw_string(font, chunk_pos + DEBUG_TEXT_SHADOW_OFFSET, text, HORIZONTAL_ALIGNMENT_LEFT, -1, DEBUG_FONT_SIZE, DEBUG_SHADOW_COLOR)
			draw_string(font, chunk_pos + DEBUG_TEXT_MAIN_OFFSET, text, HORIZONTAL_ALIGNMENT_LEFT, -1, DEBUG_FONT_SIZE, Color.WHITE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for chunk_node in chunk_nodes.values():
			if is_instance_valid(chunk_node) and chunk_node.get_parent() == null:
				chunk_node.queue_free()
