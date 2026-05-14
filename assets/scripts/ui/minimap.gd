extends Control
class_name Minimap

@export_group("Konfiguracja")
@export var level_manager : Map
@export var cell_size : float = 32.0
@export var cell_spacing : float = 4.0

@export_group("Kolory")
@export var current_room_color : Color = Color(1.0, 1.0, 1.0, 0.9)
@export var visited_room_color : Color = Color(0.6, 0.6, 0.6, 0.8) # Solidny szary (odwiedzony)
@export var discovered_not_visited_color : Color = Color(0.3, 0.3, 0.3, 0.6) # Ciemny/półprzezroczysty (widziany na mapie)
@export var background_color : Color = Color(0.0, 0.0, 0.0, 0.5)
@export var text_color : Color = Color(0.0, 0.0, 0.0, 1.0) # Kolor litery S

func _ready() -> void:
	if level_manager:
		# Podłączamy się pod sygnały informujące o dynamice gry
		level_manager.room_changed.connect(_on_map_state_changed)
		level_manager.map_updated.connect(_on_map_state_changed)
	else:
		push_warning("Minimap: Brak Map'a!")

# Ta funkcja odpala się ZAWSZE, gdy w grze doda się, usunie lub odkryje pokój
func _on_map_state_changed(_room = null) -> void:
	# queue_redraw() to silnik dynamicznego UI w Godot. 
	# Każe on wywołać funkcję _draw() od nowa w następnej klatce.
	queue_redraw() 

func _draw() -> void:
	if not level_manager or not level_manager.current_room: return
	
	var current_room = level_manager.current_room
	var center_pos = size / 2.0
	
	# Pobieramy czcionkę do narysowania litery
	var font = get_theme_default_font()
	var font_size = int(cell_size * 0.8) # Skalujemy tekst do rozmiaru komórki
	
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	for room in level_manager.all_rooms:
		if level_manager.discovered_rooms.has(room):
			var diff_x = room.map_position.x - current_room.map_position.x
			var diff_y = room.map_position.y - current_room.map_position.y
			
			var offset = Vector2(diff_x, diff_y) * (cell_size + cell_spacing)
			var box_pos = center_pos + offset - Vector2(cell_size / 2.0, cell_size / 2.0)
			var box_rect = Rect2(box_pos, Vector2(cell_size, cell_size))
			
			# --- NAPRAWIONA LOGIKA KOLORÓW ---
			var draw_color = discovered_not_visited_color # Domyślnie pokój jest tylko odkryty
			
			if room == current_room:
				draw_color = current_room_color # Jeśli to pokój, w którym obecnie jesteśmy
			elif level_manager.visited_rooms.has(room):
				draw_color = visited_room_color # Jeśli gracz już w nim był w przeszłości
			# ---------------------------------
				
			draw_rect(box_rect, draw_color)

			# --- NOWA LOGIKA: Rysowanie litery S ---
			if room == level_manager.starting_room:
				var text = "S"
				# Obliczamy rozmiar tekstu, aby go wyśrodkować
				var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				# Wyśrodkowanie tekstu wewnątrz kwadratu pokoju
				var text_pos = box_pos + (Vector2(cell_size, cell_size) / 2.0)
				text_pos.y += text_size.y / 4.0 # Mała korekta pionowa dla lepszego wyglądu
				
				draw_string(font, text_pos - Vector2(text_size.x / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
