@tool
extends Node2D
class_name Room

@export_group("Wymiary Pokoju")
@export var room_size_tiles : Vector2i = Vector2i(30, 17):
	set(value):
		value.x = max(3, value.x)
		value.y = max(3, value.y)
		room_size_tiles = value
		generate_room()
		queue_redraw()

@export_group("Ustawienia Generowania")
@export var tile_source_id : int = 0

@export_subgroup("Podłoga")
@export var floor_atlas_pos : Vector2i = Vector2i(0, 0)
## 0 to kafelek bazowy. 1, 2, 3... to kafelki alternatywne
@export var floor_alt_id : int = 0:
	set(value):
		floor_alt_id = max(0, value)
		generate_room()

@export_subgroup("Ściana")
@export var wall_atlas_pos : Vector2i = Vector2i(1, 0)
## 0 to kafelek bazowy. 1, 2, 3... to kafelki alternatywne
@export var wall_alt_id : int = 0:
	set(value):
		wall_alt_id = max(0, value)
		generate_room()

@export_group("Elementy Pokoju")
@export var tile_map : TileMapLayer
@export var navigation_region_2d : NavigationRegion2D
@export var spawn_points : Array[Marker2D] = []
## Lista węzłów reprezentujących drzwi (np. Area2D)
@export var doors : Array[Node2D] = []

var size_px : Vector2

func _ready() -> void:
	calculate_room_bounds()
	# Nie musimy już "wypiekać" nawigacji, bo rysujemy ją od razu kodem!

func generate_room() -> void:
	if not tile_map:
		return
		
	tile_map.clear()
	
	for x in range(room_size_tiles.x):
		for y in range(room_size_tiles.y):
			var current_pos = Vector2i(x, y)
			
			if x == 0 or x == room_size_tiles.x - 1 or y == 0 or y == room_size_tiles.y - 1:
				tile_map.set_cell(current_pos, tile_source_id, wall_atlas_pos, wall_alt_id)
			else:
				tile_map.set_cell(current_pos, tile_source_id, floor_atlas_pos, floor_alt_id)
	
	calculate_room_bounds()
	update_navigation_region() # Aktualizujemy obszar po wygenerowaniu kafelków

## Funkcja, która tworzy siatkę nawigacyjną idealnie na wymiar podłogi
func update_navigation_region() -> void:
	if not navigation_region_2d or not tile_map or not tile_map.tile_set:
		return
		
	var tile_size = tile_map.tile_set.tile_size
	var nav_poly = NavigationPolygon.new()
	
	# Obliczamy rogi obszaru po którym można chodzić
	# Zmiana: Punkty obejmują teraz pełny rozmiar wyznaczony przez kafelki
	var top_left = Vector2(0, 0)
	var top_right = Vector2(room_size_tiles.x * tile_size.x, 0)
	var bottom_right = Vector2(room_size_tiles.x * tile_size.x, room_size_tiles.y * tile_size.y)
	var bottom_left = Vector2(0, room_size_tiles.y * tile_size.y)
	
	# Tworzymy tablicę punktów
	var outline = PackedVector2Array([top_left, top_right, bottom_right, bottom_left])
	
	# Dodajemy obrys do poligonu i każemy Godotowi wygenerować z tego siatkę
	nav_poly.add_outline(outline)
	nav_poly.make_polygons_from_outlines()
	
	# Przypisujemy gotowy poligon do naszego węzła
	navigation_region_2d.navigation_polygon = nav_poly

func calculate_room_bounds() -> void:
	if tile_map and tile_map.tile_set:
		var tile_size = tile_map.tile_set.tile_size
		size_px = Vector2(room_size_tiles.x * tile_size.x, room_size_tiles.y * tile_size.y)

func get_random_spawn_position() -> Vector2:
	if spawn_points.is_empty():
		return global_position
	var random_marker = spawn_points.pick_random()
	return random_marker.global_position

func _draw() -> void:
	if Engine.is_editor_hint() or OS.is_debug_build():
		if tile_map and tile_map.tile_set:
			var tile_size = tile_map.tile_set.tile_size
			var rect = Rect2(Vector2.ZERO, Vector2(room_size_tiles * tile_size))
			draw_rect(rect, Color(0, 1, 0, 0.2), false, 2.0)
