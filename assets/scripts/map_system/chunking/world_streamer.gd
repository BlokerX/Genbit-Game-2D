extends Node2D
class_name WorldStreamer

@export_group("Konfiguracja Streamingu")
## Rozmiar jednego chunka w pikselach (domyślnie nadpisywany przez MapRegion z GlobalSettings)
@export var chunk_size: int  

@export_group("Debug")
## (Przeniesiono do GlobalSettings) Rysuje granice aktywnych chunków
# @export var show_chunk_grid: bool = false

var current_chunk: Vector2i = Vector2i(999999, 999999)
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

func initialize(container: Node) -> void:
	entities_container = container
	# Zaczytujemy poziom renderowania od razu na starcie
	_current_render_level = GlobalSettings.chunk_render_distance
	_last_grid_state = GlobalSettings.show_chunk_grid
	
	# 1. NATYCHMIASTOWE USTALENIE POZYCJI GRACZA (Przed dodaniem czegokolwiek!)
	player = get_tree().get_first_node_in_group("Player")
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
func _gather_streamables(node: Node, result: Array) -> void:
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
			
		# ROZPOZNAWANIE OBIEKTU: Definiujemy, co ma trafić do zamrażarki
		var is_entity = false
		if child is EntitySpawner or child.is_in_group("AdvancedSpawner"):
			is_entity = true
		elif child is CollisionObject2D or child.is_in_group("Enemy") or child.is_in_group("ItemPickup") or child.is_in_group("PlacedObject") or child.is_in_group("Hazard"):
			is_entity = true
		
		if is_entity:
			result.append(child)
		else:
			# Jeśli to zwykły "pusty folder" Node2D lub stary Marker2D, schodzimy warstwę głębiej!
			_gather_streamables(child, result)

# --- PRZEŁĄCZANIE W LOCIE (INPUT MAP) ---
func _unhandled_input(event: InputEvent) -> void:
	# Przechwytujemy akcję zdefiniowaną w Project Settings -> Input Map
	if event.is_action_pressed("ToggleChunkGrid"):
		GlobalSettings.show_chunk_grid = not GlobalSettings.show_chunk_grid
		queue_redraw()
		print("WorldStreamer: Widok siatki chunków = ", GlobalSettings.show_chunk_grid)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
		return
		
	_track_moving_entities()

	# --- NASŁUCHIWANIE ZMIAN Z MENU OPCJI ---
	var target_level = GlobalSettings.chunk_render_distance
	var level_changed = false
	if _current_render_level != target_level:
		_current_render_level = target_level
		level_changed = true

	# Aktualizacja następuje jeśli ruszył się gracz LUB ktoś zmienił zasięg suwakiem w opcjach
	var new_chunk = _calculate_chunk(player.global_position)
	if new_chunk != current_chunk or level_changed:
		current_chunk = new_chunk
		_update_active_chunks()

	# Odświeżenie rysowania jeśli wartość zmieniona w Menu Ustawień lub z palca
	if GlobalSettings.show_chunk_grid != _last_grid_state:
		_last_grid_state = GlobalSettings.show_chunk_grid
		queue_redraw()

func register_entity(node: Node) -> void:
	# TARCZA 1: Odsiewamy błędy
	if not node is Node2D: return
	if node.is_in_group("Player"): return
	if node.is_in_group("AlwaysActive"): return # Trigery ignorowane przez streamer
	
	# --- NAPRAWA KRYTYCZNA ---
	# Streamer ignoruje stare markery, ALE musi wpuścić nasz zaawansowany EntitySpawner!
	if node is Marker2D and not node is EntitySpawner: 
		return
	# -------------------------
	
	# TARCZA 2: KRYTYCZNE ZABEZPIECZENIE STRUKTURY MAPY
	if node is TileMapLayer or node is NavigationRegion2D or node is CanvasModulate or node is Camera2D: 
		return
	# Zabezpieczenie przed zjadaniem własnych chunków
	if node.name.begins_with("Chunk_") or node.name == "WorldStreamer": 
		return

	# WCHŁANIANIE: Cała reszta trafia do pudełek
	var chunk_coords = _calculate_chunk(node.global_position)
	var chunk_node = _get_or_create_chunk(chunk_coords)
	
	# --- BEZPIECZNE PRZENOSZENIE DO ZAMRAŻARKI (Clean Code) ---
	# Unikamy funkcji `node.reparent()`, która w Godot 4 rzuca błędami, gdy chunk nie jest jeszcze w drzewie.
	var global_trans = node.global_transform
	
	if node.get_parent():
		node.get_parent().remove_child(node)
		
	chunk_node.add_child(node)
	node.global_transform = global_trans
	
	# --- NAPRAWA B: Rejestrowanie w uśpionym chunku ---
	if not chunk_node.is_inside_tree() and node is RigidBody2D:
		node.freeze = true

func _track_moving_entities() -> void:
	# Skanujemy TYLKO pudełka załadowane do drzewa
	for coords in active_chunks:
		if not chunk_nodes.has(coords): continue
		var chunk_node = chunk_nodes[coords]
		
		for entity in chunk_node.get_children():
			if not is_instance_valid(entity) or entity.is_queued_for_deletion(): continue
			
			var actual_coords = _calculate_chunk(entity.global_position)
			
			# Jeśli wampir/pocisk zmienił chunk w locie
			if actual_coords != coords:
				var new_chunk_node = _get_or_create_chunk(actual_coords)
				entity.reparent(new_chunk_node, true)

func _calculate_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / chunk_size), floor(pos.y / chunk_size))

func _get_or_create_chunk(coords: Vector2i) -> Node2D:
	if chunk_nodes.has(coords): return chunk_nodes[coords]
	
	var new_chunk = Node2D.new()
	new_chunk.name = "Chunk_" + str(coords.x) + "_" + str(coords.y)
	chunk_nodes[coords] = new_chunk
	return new_chunk

## Oblicza wektory chunków wokół gracza na podstawie wybranego kształtu
func _get_offsets_for_current_level() -> Array[Vector2i]:
	# Zabezpieczenie przed wyjściem poza tablicę (zakres 1-12 zamieniamy na indeks 0-11)
	var safe_level = clampi(_current_render_level - 1, 0, RENDER_PROFILES.size() - 1)
	var profile = RENDER_PROFILES[safe_level]
	var shape = profile["shape"]
	var r = profile["radius"]
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
				# Dystans Euklidesowy: płynnie wygładza krawędzie tworząc świetne koła na siatce 2D
				if (x * x + y * y) <= (r * r) + r:
					offsets.append(Vector2i(x, y))
					
	return offsets

func _update_active_chunks() -> void:
	var new_active_chunks: Array[Vector2i] = []
	var offsets = _get_offsets_for_current_level()
	for offset in offsets:
		new_active_chunks.append(current_chunk + offset)

	# ZAMRAŻANIE
	for coords in active_chunks:
		if not new_active_chunks.has(coords):
			var chunk_node = chunk_nodes.get(coords)
			if chunk_node and chunk_node.is_inside_tree():
				# --- NAPRAWA B: Usypianie fizyki ---
				for child in chunk_node.get_children():
					if child is RigidBody2D:
						child.freeze = true
						
				entities_container.remove_child(chunk_node)

	# OŻYWIANIE
	for coords in new_active_chunks:
		if not active_chunks.has(coords):
			var chunk_node = _get_or_create_chunk(coords)
			if not chunk_node.is_inside_tree():
				entities_container.add_child(chunk_node)
				
				# --- NAPRAWA B: Budzenie fizyki ---
				for child in chunk_node.get_children():
					if child is RigidBody2D:
						child.freeze = false

	active_chunks = new_active_chunks
	if GlobalSettings.show_chunk_grid:
		queue_redraw()

func _draw() -> void:
	# Rysujemy tylko jeśli flaga globalna jest włączona
	if not GlobalSettings.show_chunk_grid:
		return

	for chunk in active_chunks:
		# Obliczamy rzeczywistą pozycję pudełka w świecie pikseli
		var chunk_pos = Vector2(chunk.x * chunk_size, chunk.y * chunk_size)
		var rect = Rect2(chunk_pos, Vector2(chunk_size, chunk_size))
		
		# 1. Rysowanie obwódki (Złoto-zielona, grubość 8 pikseli)
		draw_rect(rect, Color(0.2, 1.0, 0.4, 0.6), false, 8.0)
		
		# 2. Rysowanie bardzo delikatnego, przezroczystego tła chunka
		draw_rect(rect, Color(0.2, 1.0, 0.4, 0.05), true)
		
		# 3. Wypisywanie wielkiego napisu z koordynatami na środku
		var font = ThemeDB.fallback_font
		var font_size = 64
		if font:
			var text = "CHUNK [" + str(chunk.x) + ", " + str(chunk.y) + "]"
			# Rysujemy cień napisu
			draw_string(font, chunk_pos + Vector2(24, 84), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8))
			# Rysujemy biały napis
			draw_string(font, chunk_pos + Vector2(20, 80), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
