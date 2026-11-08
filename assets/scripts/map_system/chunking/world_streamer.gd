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

func initialize(container: Node) -> void:
	entities_container = container
	if chunk_size <= 0:
		chunk_size = GlobalSettings.chunk_base_size

	# Zaczytujemy poziom renderowania od razu na starcie
	_current_render_level = GlobalSettings.chunk_render_distance
	_last_grid_state = GlobalSettings.show_chunk_grid

	# 1. NATYCHMIASTOWE USTALENIE POZYCJI GRACZA (Przed dodaniem czegokolwiek!)
	player = get_tree().get_first_node_in_group("Player") as Node2D
	if is_instance_valid(player):
		current_chunk = _calculate_chunk(player.global_position)

	# 2. GŁĘBOKIE SKANOWANIE MAPY (Spłaszczanie struktury folderów)
	var entities_to_register: Array[Node] = []
	_gather_streamables(entities_container, entities_to_register)

	for entity in entities_to_register:
		register_entity(entity)

	# 3. NATYCHMIASTOWE WYMUSZENIE AKTUALIZACJI CHUNKÓW
	# Zanim silnik narysuje pierwszą klatkę, chowamy wszystko, czego gracz nie widzi!
	_update_active_chunks()

	set_process(true)
	if GlobalSettings.show_chunk_grid:
		queue_redraw()
	print("[WorldStreamer] Zbudowano fizyczną siatkę chunków. Aktywna hibernacja obiektów.")

## Funkcja głęboko skanująca drzewo. Wyciąga obiekty z pustych folderów Node2D.
func _gather_streamables(node: Node, result: Array[Node]) -> void:
	if node == null:
		return
	for child in node.get_children():
		# Ignorujemy systemowe węzły
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

	# Aktualizacja następuje jeśli ruszył się gracz LUB ktoś zmienił zasięg suwakiem w opcjach
	var new_chunk: Vector2i = _calculate_chunk(player.global_position)
	if new_chunk != current_chunk or level_changed:
		current_chunk = new_chunk
		_update_active_chunks()

	# Odświeżenie rysowania jeśli wartość zmieniona w Menu Ustawień lub skrótem klawiszowym
	if GlobalSettings.show_chunk_grid != _last_grid_state:
		_last_grid_state = GlobalSettings.show_chunk_grid
		queue_redraw()

func register_entity(node: Node) -> void:
	# TARCZA 1: Odsiewamy błędne lub wykluczone obiekty
	if not is_instance_valid(node) or not node is Node2D:
		return
	if node.is_in_group("Player") or node.is_in_group("AlwaysActive"):
		return

	# NAPRAWA KRYTYCZNA:
	# Streamer ignoruje zwykłe pomocnicze Marker2D (np. RespawnPoint),
	# ALE wpuszcza wszystkie zaawansowane spawnery (EntitySpawner, LootSpawner, ObjectSpawner)!
	if node is Marker2D and not (node is BaseWorldSpawner or node.is_in_group("AdvancedSpawner")):
		return

	# TARCZA 2: KRYTYCZNE ZABEZPIECZENIE STRUKTURY MAPY
	if node is TileMapLayer or node is NavigationRegion2D or node is CanvasModulate or node is Camera2D:
		return
	if node.name.begins_with("Chunk_") or node.name == "WorldStreamer":
		return

	var node_2d: Node2D = node as Node2D
	var chunk_coords: Vector2i = _calculate_chunk(node_2d.global_position)
	var chunk_node: Node2D = _get_or_create_chunk(chunk_coords)

	_transfer_node_to_chunk(node_2d, chunk_node)

## Bezpiecznie przenosi węzeł 2D do docelowego chunka, zachowując jego globalną transformację
## i zamrażając fizykę RigidBody2D, jeśli docelowy chunk jest aktualnie uśpiony poza drzewem sceny.
func _transfer_node_to_chunk(node_2d: Node2D, target_chunk_node: Node2D) -> void:
	if not is_instance_valid(node_2d) or not is_instance_valid(target_chunk_node):
		return
	if node_2d.get_parent() == target_chunk_node:
		return

	var global_trans: Transform2D = node_2d.global_transform
	var current_parent: Node = node_2d.get_parent()
	if current_parent != null:
		current_parent.remove_child(node_2d)

	target_chunk_node.add_child(node_2d)
	node_2d.global_transform = global_trans

	# Jeśli docelowy chunk jest uśpiony poza drzewem, zamrażamy fizykę RigidBody2D
	if not target_chunk_node.is_inside_tree() and node_2d is RigidBody2D:
		(node_2d as RigidBody2D).freeze = true
	elif target_chunk_node.is_inside_tree() and node_2d is RigidBody2D:
		(node_2d as RigidBody2D).freeze = false

func _track_moving_entities() -> void:
	# Skanujemy TYLKO pudełka załadowane do drzewa
	for coords in active_chunks:
		if not chunk_nodes.has(coords):
			continue
		var chunk_node: Node2D = chunk_nodes[coords]
		if not is_instance_valid(chunk_node):
			continue

		# Iterujemy po kopii tablicy dzieci, aby przeniesienie obiektu do innego chunka
		# nie modyfikowało kolekcji w trakcie pętli (naprawia pomijanie obiektów i błędy reparent)!
		var children_snapshot: Array[Node] = chunk_node.get_children()
		for entity in children_snapshot:
			if not is_instance_valid(entity) or entity.is_queued_for_deletion() or not entity is Node2D:
				continue
			# Spawnery są stacjonarne – nie musimy przeliczać ich pozycji co klatkę
			if entity is BaseWorldSpawner:
				continue

			var entity_2d: Node2D = entity as Node2D
			var actual_coords: Vector2i = _calculate_chunk(entity_2d.global_position)

			# Jeśli potwór, pocisk lub pchnięty przedmiot zmienił chunk w locie:
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
				# Dystans Manhattan: ścina narożniki tworząc kształt "diamentu / krzyża"
				if abs(x) + abs(y) <= r:
					offsets.append(Vector2i(x, y))
			elif shape == "CIRCLE":
				# Dystans Euklidesowy: płynnie wygładza krawędzie tworząc koła na siatce 2D
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
			if is_instance_valid(chunk_node) and chunk_node.is_inside_tree():
				for child in chunk_node.get_children():
					if child is RigidBody2D:
						(child as RigidBody2D).freeze = true
				entities_container.remove_child(chunk_node)

	# 2. OŻYWIANIE (Podpinanie pobliskich chunków do drzewa sceny)
	for coords in new_active_chunks:
		if not active_chunks.has(coords):
			var chunk_node: Node2D = _get_or_create_chunk(coords)
			if not chunk_node.is_inside_tree():
				entities_container.add_child(chunk_node)
				for child in chunk_node.get_children():
					if child is RigidBody2D:
						(child as RigidBody2D).freeze = false

	active_chunks = new_active_chunks
	if GlobalSettings.show_chunk_grid:
		queue_redraw()

func _draw() -> void:
	if not GlobalSettings.show_chunk_grid:
		return

	var font: Font = ThemeDB.fallback_font
	for chunk in active_chunks:
		var chunk_pos: Vector2 = Vector2(chunk.x * chunk_size, chunk.y * chunk_size)
		var rect: Rect2 = Rect2(chunk_pos, Vector2(chunk_size, chunk_size))

		# 1. Rysowanie obwódki
		draw_rect(rect, DEBUG_BORDER_COLOR, false, DEBUG_BORDER_WIDTH)
		# 2. Rysowanie półprzezroczystego tła chunka
		draw_rect(rect, DEBUG_FILL_COLOR, true)

		# 3. Wypisywanie napisu z koordynatami chunka
		if font != null:
			var text: String = "CHUNK [" + str(chunk.x) + ", " + str(chunk.y) + "]"
			draw_string(font, chunk_pos + DEBUG_TEXT_SHADOW_OFFSET, text, HORIZONTAL_ALIGNMENT_LEFT, -1, DEBUG_FONT_SIZE, DEBUG_SHADOW_COLOR)
			draw_string(font, chunk_pos + DEBUG_TEXT_MAIN_OFFSET, text, HORIZONTAL_ALIGNMENT_LEFT, -1, DEBUG_FONT_SIZE, Color.WHITE)

# Zamrożone chunki są poza drzewem, więc zwalniamy je ręcznie przy niszczeniu WorldStreamera (brak wycieków RAM).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for chunk_node in chunk_nodes.values():
			if is_instance_valid(chunk_node) and chunk_node.get_parent() == null:
				chunk_node.queue_free()
