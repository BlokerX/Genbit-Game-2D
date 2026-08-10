extends Control
class_name Minimap

#@export_group("Ikony Pokoi")
#@export var icon_treasure : Texture2D
#@export var icon_shop : Texture2D
#@export var icon_boss : Texture2D

@export_group("Konfiguracja")
@export var level_manager : Map
@export var cell_size : float = 32.0
@export var cell_spacing : float = 4.0
@export var full_view_scaller : float = 4

@export_group("Kolory")
var original_bg_color: Color
@export var current_room_color : Color = Color(1.0, 1.0, 1.0, 0.9)
@export var visited_room_color : Color = Color(0.6, 0.6, 0.6, 0.8) # Solidny szary (odwiedzony)
@export var discovered_not_visited_color : Color = Color(0.3, 0.3, 0.3, 0.6) # Ciemny/półprzezroczysty (widziany na mapie)
@export var background_color : Color = Color(0.0, 0.0, 0.0, 0.5)
@export var text_color : Color = Color(0.0, 0.0, 0.0, 1.0) # Kolor litery S

# ZMIENNE DO OBSŁUGI KLAWISZA TAB
var is_map_toggled_large: bool = false # Przechowuje informację, czy mapa jest powiększona na stałe

func _ready() -> void:
	original_bg_color = background_color
	
	# Ustawiamy punkt skalowania na prawy dolny róg
	pivot_offset = size
	
	# 1. Próbujemy złapać mapę, jeśli już tu jest (np. podczas testowania sceny)
	_try_find_map()
	
	# 2. UNIWERSALNY SYSTEM NASŁUCHIWANIA (Brak obciążenia _process!)
	# Silnik automatycznie zawoła te funkcje TYLKO WTEDY, gdy jakiś węzeł wejdzie/wyjdzie z gry
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

#region EVENT-DRIVEN MAP BINDING

func _try_find_map() -> void:
	var map_node = get_tree().get_first_node_in_group("Map")
	if map_node is Map:
		_bind_map(map_node)

## Reaguje natychmiast, gdy JAKIKOLWIEK węzeł zostanie dodany do gry (np. przez GlobalLevelManager)
func _on_node_added(node: Node) -> void:
	# Sprawdzamy czystym klasowaniem Godota 4, czy dodany węzeł to nasz Menedżer Mapy
	if node is Map:
		_bind_map(node)

## Reaguje natychmiast, gdy jakiś węzeł jest usuwany (np. queue_free starej mapy)
func _on_node_removed(node: Node) -> void:
	# Jeśli usuwają z gry naszą mapę, zdejmujemy referencję
	if node == level_manager:
		_unbind_map()

## Hermetyczna funkcja podpinająca mapę
func _bind_map(new_map: Map) -> void:
	# Jeśli to ta sama mapa, ignorujemy
	if level_manager == new_map:
		return
		
	# Odpinamy ewentualną starą mapę (zabezpieczenie przed wyciekami pamięci)
	if level_manager != null:
		_unbind_map()
		
	level_manager = new_map
	
	# Podpinamy sygnały nowej mapy
	if not level_manager.room_changed.is_connected(_on_map_state_changed):
		level_manager.room_changed.connect(_on_map_state_changed)
	if not level_manager.map_updated.is_connected(_on_map_state_changed):
		level_manager.map_updated.connect(_on_map_state_changed)
		
	# Odświeżamy rysowanie UI
	queue_redraw()

## Hermetyczna funkcja odpinająca mapę
func _unbind_map() -> void:
	if is_instance_valid(level_manager):
		if level_manager.room_changed.is_connected(_on_map_state_changed):
			level_manager.room_changed.disconnect(_on_map_state_changed)
		if level_manager.map_updated.is_connected(_on_map_state_changed):
			level_manager.map_updated.disconnect(_on_map_state_changed)
			
	level_manager = null
	queue_redraw()

#endregion

# --- ZMIENIONO: Usunięto _input. Mapa jest teraz sterowana przez UIController! ---
func toggle_large_map(is_large: bool) -> void:
	is_map_toggled_large = is_large
	_set_map_large_state(is_large)

# Nowa funkcja pomocnicza zarządzająca wyglądem mapy
func _set_map_large_state(is_large: bool) -> void:
	if is_large:
		scale = Vector2(full_view_scaller, full_view_scaller)
		clip_contents = false
		background_color.a = 0.8
	else:
		scale = Vector2(1.0, 1.0)
		clip_contents = true
		background_color = original_bg_color
		
	queue_redraw()

# Ta funkcja odpala się ZAWSZE, gdy w grze doda się, usunie lub odkryje pokój
func _on_map_state_changed(_room = null) -> void:
	# queue_redraw() to silnik dynamicznego UI w Godot. 
	# Każe on wywołać funkcję _draw() od nowa w następnej klatce.
	queue_redraw() 

func _draw() -> void:
	if not level_manager or not level_manager.current_room: return
	
	var current_room = level_manager.current_room
	var center_pos = size / 2.0
	
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	var reference_pos = current_room.map_position
	var current_zoom = 1.0 # NOWA ZMIENNA: Domyślny mnożnik skalowania
	
	# --- NOWA LOGIKA: CENTROWANIE I DYNAMICZNE SKALOWANIE MAPY ---
	if is_map_toggled_large and level_manager.discovered_rooms.size() > 0:
		var min_pos = Vector2(INF, INF)
		var max_pos = Vector2(-INF, -INF)
		
		# Szukamy skrajnych współrzędnych odkrytej mapy
		for r in level_manager.discovered_rooms:
			min_pos.x = min(min_pos.x, r.map_position.x)
			min_pos.y = min(min_pos.y, r.map_position.y)
			max_pos.x = max(max_pos.x, r.map_position.x)
			max_pos.y = max(max_pos.y, r.map_position.y)
			
		reference_pos = (min_pos + max_pos) / 2.0
		
		# Obliczanie fizycznego rozmiaru całej odkrytej siatki w pikselach
		var grid_w = max_pos.x - min_pos.x + 1
		var grid_h = max_pos.y - min_pos.y + 1
		
		var map_pixel_w = grid_w * (cell_size + cell_spacing)
		var map_pixel_h = grid_h * (cell_size + cell_spacing)
		
		# Jeśli mapa jest większa niż tło, pomniejszamy ją tak, by się zmieściła
		if map_pixel_w > size.x or map_pixel_h > size.y:
			# Wybieramy mniejszy współczynnik (by cała mapa się zmieściła) i mnożymy przez 0.9 dla 10% marginesu na krawędziach
			current_zoom = min(size.x / map_pixel_w, size.y / map_pixel_h) * 0.9
	# -------------------------------------

	# Aplikujemy nasz wyliczony "zoom" do rozmiaru komórek i odstępów
	var actual_cell_size = cell_size * current_zoom
	var actual_spacing = cell_spacing * current_zoom

	# Pobieramy czcionkę i adaptujemy jej wielkość, zapobiegając błędowi wielkości < 1
	var font = get_theme_default_font()
	var font_size = max(1, int(actual_cell_size * 0.8)) 

	for room in level_manager.all_rooms:
		if level_manager.discovered_rooms.has(room):
			
			var diff_x = room.map_position.x - reference_pos.x
			var diff_y = room.map_position.y - reference_pos.y
			
			# Używamy przeskalowanych wartości do ułożenia siatki
			var offset = Vector2(diff_x, diff_y) * (actual_cell_size + actual_spacing)
			var box_pos = center_pos + offset - Vector2(actual_cell_size / 2.0, actual_cell_size / 2.0)
			var box_rect = Rect2(box_pos, Vector2(actual_cell_size, actual_cell_size))
			
			# --- NAPRAWIONA LOGIKA KOLORÓW ---
			var draw_color = discovered_not_visited_color # Domyślnie pokój jest tylko odkryty
			
			if room == current_room:
				draw_color = current_room_color # Jeśli to pokój, w którym obecnie jesteśmy
			elif level_manager.visited_rooms.has(room):
				draw_color = visited_room_color # Jeśli gracz już w nim był w przeszłości
			# ---------------------------------
				
			draw_rect(box_rect, draw_color)
			
			# --- Rysowanie litery S ---
			if room == level_manager.starting_room:
				var text = "S"
				var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				var text_pos = box_pos + (Vector2(actual_cell_size, actual_cell_size) / 2.0)
				text_pos.y += text_size.y / 4.0 
				
				draw_string(font, text_pos - Vector2(text_size.x / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
			
			# --- Sprawdzanie czy na ziemi leżą itemy (ItemPickup) ---
			if level_manager.visited_rooms.has(room):
				var target_parent = room
				var loot_icons_to_draw : Array[Texture2D] = []
				
				for child in target_parent.get_children():
					# Sprawdzamy, czy to podnoszony przedmiot i czy nowa instancja (item) oraz jej dane (data) istnieją
					if child is ItemPickup and child.item != null and child.item.data != null and child.item.data.item_icon != null:
		
						# Pobieramy ikonę ze zaktualizowanej ścieżki
						var item_tex = child.item.data.item_icon
		
						if not loot_icons_to_draw.has(item_tex):
							loot_icons_to_draw.append(item_tex)
				
				# Skalujemy również rozmiar ikonek i ich padding wewnątrz pokoju
				var base_icon_size = Vector2(10, 10) 
				var loot_icon_size = base_icon_size * current_zoom
				var spacing = 2.0 * current_zoom
				var padding = 1.0 * current_zoom
				
				var current_x_offset = 0.0
				var current_y_offset = 0.0
				
				for tex in loot_icons_to_draw:
					# Zabezpieczenie przed wychodzeniem ikonek poza aktualny obszar komórki
					if current_x_offset + loot_icon_size.x + spacing > actual_cell_size:
						current_x_offset = 0.0
						current_y_offset += loot_icon_size.y + padding
						
					if current_y_offset + loot_icon_size.y + spacing > actual_cell_size:
						break
					
					var loot_icon_pos = box_pos + Vector2(
						actual_cell_size - loot_icon_size.x - spacing - current_x_offset, 
						actual_cell_size - loot_icon_size.y - spacing - current_y_offset
					)
					
					draw_texture_rect(tex, Rect2(loot_icon_pos, loot_icon_size), false)
					current_x_offset += loot_icon_size.x + padding
