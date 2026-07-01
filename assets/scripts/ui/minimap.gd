extends Control
class_name Minimap

#@export_group("Ikony Pokoi")
#@export var icon_treasure : Texture2D
#@export var icon_shop : Texture2D
#@export var icon_boss : Texture2D

@export_group("Ikony Ziemnego Lootu")
@export var drop_icon_weapon : Texture2D
@export var drop_icon_eatable : Texture2D
@export var drop_icon_other : Texture2D

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

func _ready() -> void:
	original_bg_color = background_color
	
	# Ustawiamy punkt skalowania na prawy górny róg.
	# Dzięki temu mapa przy powiększaniu rozleje się w dół i w lewo (do środka ekranu)
	pivot_offset = size
	
	if level_manager:
		# Podłączamy się pod sygnały informujące o dynamice gry
		level_manager.room_changed.connect(_on_map_state_changed)
		level_manager.map_updated.connect(_on_map_state_changed)
	else:
		push_warning("Minimap: Brak Map'a!")

# Wychwytywanie wciśnięcia i puszczenia klawisza TAB
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB:
		
		# Klawisz TAB ZOSTANIE WCIŚNIĘTY (i ignorujemy "przytrzymanie/echo" systemu)
		if event.is_pressed() and not event.is_echo():
			scale = Vector2(full_view_scaller, full_view_scaller) # Powiększamy mapę 2.5 raza (możesz dostosować tę wartość)
			clip_contents = false     # Magia! Pokazujemy wszystkie pokoje wystające poza standardową ramkę
			background_color.a = 0.8  # Przyciemniamy czarne tło dla lepszej czytelności
			queue_redraw()
			
		# Klawisz TAB ZOSTAJE PUSZCZONY
		elif not event.is_pressed():
			scale = Vector2(1.0, 1.0) # Wracamy do oryginalnego rozmiaru
			clip_contents = true      # Z powrotem ucinamy widok do małego kwadratu w rogu
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
			
			# --- NOWA LOGIKA: Rysowanie Ikony Pokoju ---
			#match room.room_type:
				#Room.RoomType.TREASURE:
					#icon_to_draw = icon_treasure
				#Room.RoomType.SHOP:
					#icon_to_draw = icon_shop
				#Room.RoomType.BOSS:
					#icon_to_draw = icon_boss
					
			# --- Rysowanie litery S ---
			if room == level_manager.starting_room:
				var text = "S"
				# Obliczamy rozmiar tekstu, aby go wyśrodkować
				var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				# Wyśrodkowanie tekstu wewnątrz kwadratu pokoju
				var text_pos = box_pos + (Vector2(cell_size, cell_size) / 2.0)
				text_pos.y += text_size.y / 4.0 # Mała korekta pionowa dla lepszego wyglądu
				
				draw_string(font, text_pos - Vector2(text_size.x / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
			# Jeśli przypisano ikonkę dla tego typu pokoju, narysuj ją!
			#elif icon_to_draw != null:
				## Zmniejszamy prostokąt, żeby ikonka miała margines (nie dotykała krawędzi)
				#var icon_rect = box_rect.grow(-4) 
				## Rysujemy teksturę na minimapie
				#draw_texture_rect(icon_to_draw, icon_rect, false)
			
			
			# --- Sprawdzanie czy na ziemi leżą itemy (ItemPickup) ---
			# W the Binding of Isaac widzimy itemy tylko w pokojach, które już odwiedziliśmy
			if level_manager.visited_rooms.has(room):
				
				# Szukamy miejsca, w którym LevelManager ładuje przedmioty
				var target_parent = room
				
				# Tworzymy listę oryginalnych tekstur do narysowania w tym pokoju
				var loot_icons_to_draw : Array[Texture2D] = []
				
				# Przeszukujemy dzieci w poszukiwaniu rzuconych itemów
				for child in target_parent.get_children():
					if child is ItemPickup and child.item_data != null and child.item_data.item_icon != null:
						var item_tex = child.item_data.item_icon
						
						# Zabezpieczenie: Jeśli leżą 3 takie same miecze, rysujemy tylko jedną ikonę
						if not loot_icons_to_draw.has(item_tex):
							loot_icons_to_draw.append(item_tex)
				
				# Rysujemy zebrane ikony
				var loot_icon_size = Vector2(10, 10) # Rozmiar miniatury na mapie (np. 10x10 px)
				var current_x_offset = 0
				var current_y_offset = 0
				
				for tex in loot_icons_to_draw:
					# Zabezpieczenie X: Jeśli ikona wyszłaby poza lewą krawędź pokoju, przenieś ją do wyższego rzędu
					if current_x_offset + loot_icon_size.x + 2 > cell_size:
						current_x_offset = 0
						current_y_offset += loot_icon_size.y + 1
						
					# Zabezpieczenie Y: Jeśli ikony wyszłyby poza górną krawędź pokoju, po prostu przestań je rysować (pokój jest pełny)
					if current_y_offset + loot_icon_size.y + 2 > cell_size:
						break
					
					# Obliczamy pozycję (prawy dolny róg, przesuwany w lewo i w górę)
					var loot_icon_pos = box_pos + Vector2(
						cell_size - loot_icon_size.x - 2 - current_x_offset, 
						cell_size - loot_icon_size.y - 2 - current_y_offset
					)
					
					# Rysujemy oryginalną ikonę ze skalowaniem do rozmiaru loot_icon_size
					draw_texture_rect(tex, Rect2(loot_icon_pos, loot_icon_size), false)
					
					# Zwiększamy offset, aby kolejna ikona narysowała się obok
					current_x_offset += loot_icon_size.x + 1
