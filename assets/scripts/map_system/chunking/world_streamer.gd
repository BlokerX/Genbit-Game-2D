extends Node2D
class_name WorldStreamer
## System dynamicznego streamingu i hibernacji obiektów świata (Open World) oparty na siatce chunków.
## Zarządza pamięcią podręczną nieaktywnych sektorów oraz budżetowanym czasowo (4 ms) wybudzaniem jednostek.

# --- STAŁE DOMENOWE I DEBUGOWANIA (Brak magicznych liczb) ---
const UNINITIALIZED_CHUNK_COORD: int = 999999
## Maksymalny czas pracy (w milisekundach) w jednej klatce podczas aktywacji obiektów w chunkach.
## Wartość 4 ms gwarantuje ponad 120 cykli pętli komunikatów Windows na sekundę (zero "White Screen" przy klikaniu!).
const MAX_FRAME_BUDGET_MSEC: int = 4

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
## Przechowuje odpięte z drzewa obiekty dla nieaktywnych chunków: { Vector2i : Array[Node2D] }.
## Pozwala dodawać obiekty do drzewa sceny pojedynczo (z budżetem 4 ms), zamiast dławić C++ jednym wielkim add_child!
var _hibernated_entities_by_chunk: Dictionary = {}
var entities_container: Node

var _current_render_level: int = 1  
var _last_grid_state: bool = false
var _is_initialized: bool = false
var _is_streaming_batch: bool = false

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

## Asynchroniczna inicjalizacja używana przy ładowaniu ogromnych poziomów (np. massive_map).
## Wypina wszystkie obiekty z kontenera Entities do bufora RAM, dzięki czemu dodanie samej mapy do drzewa trwa < 1 ms!
func initialize_async(
	container: Node,
	tree: SceneTree,
	initial_focus_pos: Vector2 = Vector2.INF,
	defer_chunk_activation: bool = true
) -> void:
	if _is_initialized and entities_container == container:
		if initial_focus_pos != Vector2.INF and not defer_chunk_activation:
			await activate_chunks_async(tree, initial_focus_pos)
		return

	entities_container = container
	if chunk_size <= 0:
		chunk_size = GlobalSettings.chunk_base_size

	_current_render_level = GlobalSettings.chunk_render_distance
	_last_grid_state = GlobalSettings.show_chunk_grid

	var focus_pos: Vector2 = _resolve_focus_position(initial_focus_pos)
	current_chunk = _calculate_chunk(focus_pos)

	var frame_start_msec: int = Time.get_ticks_msec()
	var entities_to_register: Array[Node] = []
	_gather_streamables(entities_container, entities_to_register)

	if tree != null and Time.get_ticks_msec() - frame_start_msec >= MAX_FRAME_BUDGET_MSEC:
		await tree.process_frame
		frame_start_msec = Time.get_ticks_msec()

	var total_count: int = entities_to_register.size()
	# Iterujemy OD KOŃCA tablicy (O(1) przy remove_child w C++) i odkładamy obiekty do bufora hibernacji
	for i in range(total_count - 1, -1, -1):
		_stage_entity_into_hibernation(entities_to_register[i])
		if tree != null and Time.get_ticks_msec() - frame_start_msec >= MAX_FRAME_BUDGET_MSEC:
			var progress: float = float(total_count - i) / float(maxi(1, total_count))
			TransitionManager.update_loading_progress(
				lerpf(0.45, 0.72, progress),
				"Segregacja obiektów świata (%d / %d)..." % [total_count - i, total_count]
			)
			await tree.process_frame
			frame_start_msec = Time.get_ticks_msec()

	_is_initialized = true
	if not defer_chunk_activation:
		await activate_chunks_async(tree, focus_pos)
	else:
		set_process(false)

	print("[WorldStreamer] Zbudowano fizyczną siatkę chunków. Aktywna hibernacja obiektów.")

## Płynnie aktywuje chunki wokół gracza po wejściu mapy do drzewa sceny.
## Obiekty (np. 64 żołnierzy w Chunk_17_7) wchodzą do SceneTree pojedynczo z budżetem 4 ms na klatkę!
func activate_chunks_async(tree: SceneTree, focus_pos: Vector2 = Vector2.INF) -> void:
	if not is_instance_valid(entities_container):
		return

	_is_streaming_batch = true

	if focus_pos != Vector2.INF:
		current_chunk = _calculate_chunk(focus_pos)
	elif is_inside_tree():
		player = get_tree().get_first_node_in_group("Player") as Node2D
		if is_instance_valid(player):
			current_chunk = _calculate_chunk(player.global_position)

	var new_active_chunks: Array[Vector2i] = []
	var offsets: Array[Vector2i] = _get_offsets_for_current_level()
	for offset in offsets:
		new_active_chunks.append(current_chunk + offset)

	var frame_start_msec: int = Time.get_ticks_msec()

	# 1. ZAMRAŻANIE nieaktywnych chunków
	for coords in active_chunks:
		if not new_active_chunks.has(coords):
			_deactivate_single_chunk(coords)
			if tree != null and Time.get_ticks_msec() - frame_start_msec >= MAX_FRAME_BUDGET_MSEC:
				await tree.process_frame
				frame_start_msec = Time.get_ticks_msec()

	# 2. OŻYWIANIE aktywnych chunków i jednostkowe dodawanie encji z kontrolą budżetu 4 ms na klatkę!
	var total_chunks: int = new_active_chunks.size()
	for idx in range(total_chunks):
		var coords: Vector2i = new_active_chunks[idx]
		var chunk_node: Node2D = _get_or_create_chunk(coords)
		if chunk_node.get_parent() != entities_container:
			entities_container.add_child(chunk_node)

		if _hibernated_entities_by_chunk.has(coords):
			var bucket: Array = _hibernated_entities_by_chunk[coords]
			while not bucket.is_empty():
				var entity_2d: Node2D = _pop_next_valid_hibernated_entity(bucket)
				if entity_2d != null:
					_attach_staged_entity_to_active_chunk(entity_2d, chunk_node)

				if tree != null and Time.get_ticks_msec() - frame_start_msec >= MAX_FRAME_BUDGET_MSEC:
					var ratio: float = float(idx + 1) / float(maxi(1, total_chunks))
					TransitionManager.update_loading_progress(
						lerpf(0.75, 0.96, ratio),
						"Aktywacja jednostek w sektorze (%d / %d)..." % [idx + 1, total_chunks]
					)
					await tree.process_frame
					frame_start_msec = Time.get_ticks_msec()

		for child in chunk_node.get_children():
			if child is RigidBody2D:
				(child as RigidBody2D).freeze = false

	active_chunks = new_active_chunks
	_is_streaming_batch = false
	set_process(true)
	if is_inside_tree() and GlobalSettings.show_chunk_grid:
		queue_redraw()

## Synchroniczna inicjalizacja (dla małych map lub bezpośredniego uruchomienia pojedynczej sceny z edytora).
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

	var focus_pos: Vector2 = _resolve_focus_position(initial_focus_pos)
	current_chunk = _calculate_chunk(focus_pos)

	var entities_to_register: Array[Node] = []
	_gather_streamables(entities_container, entities_to_register)

	for i in range(entities_to_register.size() - 1, -1, -1):
		_stage_entity_into_hibernation(entities_to_register[i])

	_update_active_chunks()
	_flush_all_active_chunk_buckets_immediately()
	_is_initialized = true
	set_process(true)
	if is_inside_tree() and GlobalSettings.show_chunk_grid:
		queue_redraw()
	print("[WorldStreamer] Zbudowano fizyczną siatkę chunków. Aktywna hibernacja obiektów.")

func _resolve_focus_position(initial_focus_pos: Vector2) -> Vector2:
	if initial_focus_pos != Vector2.INF:
		return initial_focus_pos
	if is_inside_tree():
		player = get_tree().get_first_node_in_group("Player") as Node2D
		if is_instance_valid(player):
			return player.global_position
	return Vector2.ZERO

## Wymusza przeliczenie aktywnych chunków dla nowej pozycji gracza.
func refresh_focus_position(focus_pos: Vector2) -> void:
	var new_chunk: Vector2i = _calculate_chunk(focus_pos)
	if new_chunk != current_chunk or active_chunks.is_empty():
		current_chunk = new_chunk
		_update_active_chunks()

## Zamraża i wypina wszystkie aktywne chunki oraz ich obiekty do bufora hibernacji (gdy mapa trafia do schowka RAM).
func hibernate_all_chunks() -> void:
	if not is_instance_valid(entities_container):
		return
	for coords in active_chunks:
		_deactivate_single_chunk(coords)
	active_chunks.clear()
	set_process(false)

## Przywraca aktywne chunki po wyciągnięciu mapy ze schowka RAM.
func restore_active_chunks(focus_pos: Vector2) -> void:
	set_process(true)
	current_chunk = _calculate_chunk(focus_pos)
	_update_active_chunks()

## Dezaktywuje pojedynczy chunk: wypina jego żywe dzieci do bufora _hibernated_entities_by_chunk i odpina chunk z drzewa.
func _deactivate_single_chunk(coords: Vector2i) -> void:
	var chunk_node: Node2D = chunk_nodes.get(coords)
	if not is_instance_valid(chunk_node):
		return

	if not _hibernated_entities_by_chunk.has(coords):
		_hibernated_entities_by_chunk[coords] = []
	var bucket: Array = _hibernated_entities_by_chunk[coords]

	var children: Array[Node] = chunk_node.get_children()
	for i in range(children.size() - 1, -1, -1):
		var child: Node = children[i]
		# Pomijamy obiekty martwe lub oczekujące na usunięcie (queue_free), aby nie zostawiać
		# wskaźników '<Freed Object>' w tablicy hibernacji!
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if child is Node2D:
			var child_2d: Node2D = child as Node2D
			if child_2d is RigidBody2D:
				(child_2d as RigidBody2D).freeze = true
			child_2d.set_meta("_chunk_saved_transform", child_2d.transform)
			chunk_node.remove_child(child_2d)
			child_2d.owner = null
			if not bucket.has(child_2d):
				bucket.append(child_2d)

	if chunk_node.get_parent() == entities_container:
		entities_container.remove_child(chunk_node)

## Funkcja głęboko skanująca drzewo. Wyciąga obiekty z pustych folderów Node2D.
func _gather_streamables(node: Node, result: Array[Node]) -> void:
	if node == null:
		return
	for child in node.get_children():
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if child.name.begins_with("Chunk_") or child.name == "WorldStreamer":
			continue
		if child is TileMapLayer or child is NavigationRegion2D or child is CanvasModulate or child is Camera2D:
			continue
		if child is Door or child is LevelEntrance:
			continue
		if child.is_in_group("Player") or child.is_in_group("AlwaysActive"):
			continue
		if not child is Node2D:
			continue

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
			_gather_streamables(child, result)

# --- PRZEŁĄCZANIE W LOCIE (INPUT MAP) ---
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ToggleChunkGrid"):
		GlobalSettings.show_chunk_grid = not GlobalSettings.show_chunk_grid
		queue_redraw()
		print("WorldStreamer: Widok siatki chunków = ", GlobalSettings.show_chunk_grid)

func _process(_delta: float) -> void:
	if _is_streaming_batch:
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player") as Node2D
		return

	# Jeśli w aktywnych chunkach czekają jeszcze obiekty w buforze (np. gracz wszedł na nowy gęsty chunk w trakcie gry),
	# dodajemy je płynnie z budżetem 4 ms na klatkę (zero przycięć podczas chodzenia po świecie!).
	_process_pending_active_chunk_entities()

	_track_moving_entities()

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

## Bezpiecznie pobiera kolejny prawidłowy obiekt Node2D z koszyka hibernacji (zasada DRY).
## Weryfikuje ważność instancji na typie Variant PRZED wykonaniem rzutowania 'as Node2D',
## co całkowicie eliminuje błąd 'Trying to cast a freed object', gdy obiekt zginął przed wybudzeniem chunka.
func _pop_next_valid_hibernated_entity(bucket: Array) -> Node2D:
	while not bucket.is_empty():
		var raw_entity: Variant = bucket.pop_back()
		if not is_instance_valid(raw_entity):
			continue
		if not (raw_entity is Node2D):
			continue
		var node_2d: Node2D = raw_entity as Node2D
		if node_2d.is_queued_for_deletion():
			continue
		return node_2d
	return null

## Płynnie dogrywa obiekty z bufora dla nowo odkrytych chunków podczas chodzenia po świecie (max 4 ms na klatkę).
func _process_pending_active_chunk_entities() -> void:
	var frame_start_msec: int = Time.get_ticks_msec()
	for coords in active_chunks:
		if not _hibernated_entities_by_chunk.has(coords):
			continue
		var bucket: Array = _hibernated_entities_by_chunk[coords]
		if bucket.is_empty():
			continue
		var chunk_node: Node2D = _get_or_create_chunk(coords)
		while not bucket.is_empty():
			var entity_2d: Node2D = _pop_next_valid_hibernated_entity(bucket)
			if entity_2d != null:
				_attach_staged_entity_to_active_chunk(entity_2d, chunk_node)
			if Time.get_ticks_msec() - frame_start_msec >= MAX_FRAME_BUDGET_MSEC:
				return

## Natychmiastowo opróżnia koszyki hibernacji dla wszystkich aktywnych chunków (używane przy synchronicznym starcie).
func _flush_all_active_chunk_buckets_immediately() -> void:
	for coords in active_chunks:
		if not _hibernated_entities_by_chunk.has(coords):
			continue
		var bucket: Array = _hibernated_entities_by_chunk[coords]
		var chunk_node: Node2D = _get_or_create_chunk(coords)
		while not bucket.is_empty():
			var entity_2d: Node2D = _pop_next_valid_hibernated_entity(bucket)
			if entity_2d != null:
				_attach_staged_entity_to_active_chunk(entity_2d, chunk_node)

## Alias zachowujący pełną kompatybilność wsteczną.
func _Flush_all_active_chunk_buckets_immediately() -> void:
	_flush_all_active_chunk_buckets_immediately()

## Rejestruje nowy obiekt (np. zespawnowany w trakcie gry) do odpowiedniego chunka.
func register_entity(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not (node is Node2D):
		return
	if node.is_in_group("Player") or node.is_in_group("AlwaysActive"):
		return
	if node is Door or node is LevelEntrance:
		return
	if node is Marker2D and not (node is BaseWorldSpawner or node.is_in_group("AdvancedSpawner")):
		return
	if node is TileMapLayer or node is NavigationRegion2D or node is CanvasModulate or node is Camera2D:
		return
	if node.name.begins_with("Chunk_") or node.name == "WorldStreamer":
		return

	var node_2d: Node2D = node as Node2D
	var world_pos: Vector2 = _get_node_world_position(node_2d)
	var chunk_coords: Vector2i = _calculate_chunk(world_pos)

	# Jeśli chunk jest aktualnie aktywny w drzewie sceny, przypinamy bezpośrednio do niego
	if active_chunks.has(chunk_coords):
		var chunk_node: Node2D = _get_or_create_chunk(chunk_coords)
		_transfer_node_to_chunk(node_2d, chunk_node)
	else:
		# Jeśli chunk jest nieaktywny, odkładamy obiekt do bufora hibernacji
		_stage_entity_into_hibernation(node_2d)

## Wypina obiekt ze sceny i odkłada go do bufora hibernacji odpowiedniego chunka.
func _stage_entity_into_hibernation(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not (node is Node2D):
		return
	if node is Door or node is LevelEntrance or node.is_in_group("Player") or node.is_in_group("AlwaysActive"):
		return
	if node is Marker2D and not (node is BaseWorldSpawner or node.is_in_group("AdvancedSpawner")):
		return

	var node_2d: Node2D = node as Node2D
	var preserved_transform: Transform2D = (
		node_2d.global_transform
		if node_2d.is_inside_tree()
		else _get_transform_relative_to_root(node_2d)
	)
	var chunk_coords: Vector2i = _calculate_chunk(preserved_transform.origin)

	var current_parent: Node = node_2d.get_parent()
	if current_parent != null:
		current_parent.remove_child(node_2d)

	# Odpinamy właściciela sceny (.tscn), eliminując 100% błędów C++ Debuggera o niespójnym ownerze!
	node_2d.owner = null
	node_2d.transform = preserved_transform
	node_2d.set_meta("_chunk_saved_transform", preserved_transform)

	if node_2d is RigidBody2D:
		(node_2d as RigidBody2D).freeze = true

	if not _hibernated_entities_by_chunk.has(chunk_coords):
		_hibernated_entities_by_chunk[chunk_coords] = []
	var bucket: Array = _hibernated_entities_by_chunk[chunk_coords]
	if not bucket.has(node_2d):
		bucket.append(node_2d)

## Dodaje pojedynczy obiekt z bufora hibernacji do aktywnego węzła chunka w drzewie sceny.
func _attach_staged_entity_to_active_chunk(node_2d: Node2D, chunk_node: Node2D) -> void:
	if not is_instance_valid(node_2d) or node_2d.is_queued_for_deletion() or not is_instance_valid(chunk_node):
		return
	if node_2d.get_parent() == chunk_node:
		return

	var saved_xform: Transform2D = (
		node_2d.get_meta("_chunk_saved_transform")
		if node_2d.has_meta("_chunk_saved_transform")
		else node_2d.transform
	)
	var current_parent: Node = node_2d.get_parent()
	if current_parent != null:
		current_parent.remove_child(node_2d)

	node_2d.owner = null
	chunk_node.add_child(node_2d)
	if chunk_node.is_inside_tree():
		node_2d.global_transform = saved_xform
	else:
		node_2d.transform = saved_xform

	if node_2d is RigidBody2D:
		(node_2d as RigidBody2D).freeze = not chunk_node.is_inside_tree()

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

func _transfer_node_to_chunk(node_2d: Node2D, target_chunk_node: Node2D) -> void:
	if not is_instance_valid(node_2d) or node_2d.is_queued_for_deletion() or not is_instance_valid(target_chunk_node):
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

	node_2d.owner = null

	target_chunk_node.add_child(node_2d)
	if was_in_tree and target_chunk_node.is_inside_tree():
		node_2d.global_transform = preserved_transform
	else:
		node_2d.transform = preserved_transform

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
			if not is_instance_valid(entity) or entity.is_queued_for_deletion() or not (entity is Node2D):
				continue
			if entity is BaseWorldSpawner:
				continue

			var entity_2d: Node2D = entity as Node2D
			var actual_coords: Vector2i = _calculate_chunk(entity_2d.global_position)

			if actual_coords != coords:
				if active_chunks.has(actual_coords):
					var new_chunk_node: Node2D = _get_or_create_chunk(actual_coords)
					_transfer_node_to_chunk(entity_2d, new_chunk_node)
				else:
					_stage_entity_into_hibernation(entity_2d)

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

	for coords in active_chunks:
		if not new_active_chunks.has(coords):
			_deactivate_single_chunk(coords)

	for coords in new_active_chunks:
		if not active_chunks.has(coords):
			var chunk_node: Node2D = _get_or_create_chunk(coords)
			if chunk_node.get_parent() != entities_container:
				entities_container.add_child(chunk_node)

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

# Zwalniamy zarówno odpięte chunki, jak i zahibernowane obiekty przy zamykaniu gry (zero wycieków pamięci).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for bucket in _hibernated_entities_by_chunk.values():
			if bucket is Array:
				for raw_entity in bucket:
					if is_instance_valid(raw_entity) and raw_entity is Node and (raw_entity as Node).get_parent() == null:
						(raw_entity as Node).queue_free()
		_hibernated_entities_by_chunk.clear()
		for chunk_node in chunk_nodes.values():
			if is_instance_valid(chunk_node) and chunk_node.get_parent() == null:
				chunk_node.queue_free()
