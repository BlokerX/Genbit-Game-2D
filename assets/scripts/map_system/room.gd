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
@export var floor_alt_id : int = 0:
	set(value):
		floor_alt_id = max(0, value)
		generate_room()

@export_subgroup("Ściana")
@export var wall_atlas_pos : Vector2i = Vector2i(1, 0)
@export var wall_alt_id : int = 0:
	set(value):
		wall_alt_id = max(0, value)
		generate_room()

@export_group("Drzwi")
var doors : Array[Door] = []

@export_group("Elementy Pokoju")
@onready var tile_map : TileMapLayer = $TileMap
@onready var navigation_region_2d : NavigationRegion2D = $NavigationRegion2D
@export var spawn_points : Array[Marker2D] = []

var size_px : Vector2

func _ready() -> void:
	# Ta linijka sprawia, że gra po uruchomieniu zbuduje kafelki i zespawnuje drzwi!
	generate_room()
	
	# Automatyczne pobieranie drzwi przy starcie sceny
	# Ignorujemy działanie w edytorze, jeśli nie jest nam tam potrzebne do logiki
	if not Engine.is_editor_hint():
		_auto_fetch_doors()

# NOWA FUNKCJA: Główna funkcja wywoływana do zebrania drzwi
func _auto_fetch_doors() -> void:
	doors.clear() # Czyścimy listę dla pewności
	_find_doors_recursive(self) # Zaczynamy szukać od samego pokoju (self)
	print("Pokój " + name + " znalazł automatycznie " + str(doors.size()) + " drzwi.")

# NOWA FUNKCJA: Rekurencyjne szukanie (znajdzie drzwi nawet jeśli są zgrupowane w innym Node2D)
func _find_doors_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Door:
			# Zaleźliśmy obiekt klasy Door! Dodajemy do listy.
			doors.append(child)
		
		# Niezależnie od tego, czy to drzwi czy nie, szukamy też w dzieciach tego węzła.
		# Pozwala to trzymać drzwi w "folderach" np. Node2D o nazwie "Doors".
		if child.get_child_count() > 0:
			_find_doors_recursive(child)

func generate_room() -> void:
	if not tile_map: return
	
	tile_map.clear()

	# 1. Rysowanie kafelków
	for x in range(room_size_tiles.x):
		for y in range(room_size_tiles.y):
			var current_pos = Vector2i(x, y)
			
			# Rysowanie ścian i podłogi
			if x == 0 or x == room_size_tiles.x - 1 or y == 0 or y == room_size_tiles.y - 1:
				tile_map.set_cell(current_pos, tile_source_id, wall_atlas_pos, wall_alt_id)
			else:
				tile_map.set_cell(current_pos, tile_source_id, floor_atlas_pos, floor_alt_id)
	
	calculate_room_bounds()
	update_navigation_region()

func update_navigation_region() -> void:
	if not navigation_region_2d or not tile_map or not tile_map.tile_set: return
	var tile_size = tile_map.tile_set.tile_size
	var nav_poly = NavigationPolygon.new()
	var outline = PackedVector2Array([
		Vector2(0, 0),
		Vector2(room_size_tiles.x * tile_size.x, 0),
		Vector2(room_size_tiles.x * tile_size.x, room_size_tiles.y * tile_size.y),
		Vector2(0, room_size_tiles.y * tile_size.y)
	])
	nav_poly.add_outline(outline)
	nav_poly.make_polygons_from_outlines()
	navigation_region_2d.navigation_polygon = nav_poly

func calculate_room_bounds() -> void:
	if tile_map and tile_map.tile_set:
		var tile_size = tile_map.tile_set.tile_size
		size_px = Vector2(room_size_tiles.x * tile_size.x, room_size_tiles.y * tile_size.y)

func _draw() -> void:
	if Engine.is_editor_hint() or OS.is_debug_build():
		if tile_map and tile_map.tile_set:
			var tile_size = tile_map.tile_set.tile_size
			var rect = Rect2(Vector2.ZERO, Vector2(room_size_tiles * tile_size))
			draw_rect(rect, Color(0, 1, 0, 0.2), false, 2.0)
