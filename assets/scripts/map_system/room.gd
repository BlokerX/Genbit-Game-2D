@tool
extends Node2D
## Pokój
class_name Room

const ENEMY_GROUP = "Enemy"

@export_group("Mapa")
## Pozycja pokoju na siatce minimapy (np. 0,0 to start, 1,0 to pokój po prawej)
@export var map_position : Vector2i = Vector2i.ZERO


@export_group("Typ i Znaczenie Pokoju")

enum RoomType { NORMAL, START, TREASURE, SHOP, BOSS, DEV_ROOM, ARENA }

## Określa typ pokoju. Przydatne dla Minimapy (ikony), Menedżera Muzyki oraz logiki gry.
@export var room_type: RoomType = RoomType.NORMAL

## Jeśli prawda, pokój pojawi się na mapie dopiero po wejściu do niego
@export var is_secret : bool = false

@export_group("Logika Walki i Ograniczenia")
## Strefa Bezpieczna: pokój NIGDY nie zablokuje drzwi (idealne dla Sklepów i Dev Rooma).
@export var ignore_combat_lock: bool = false

## Klatka (One-Way): Gdy gracz wejdzie do pokoju, drzwi się zamkną i NIE otworzą nawet po zabiciu wrogów. (Pokoje Bossa, pułapki).
@export var lock_permanently_after_entry: bool = false

## Pacyfizm: Jeśli włączone, gracz ma zablokowaną możliwość używania broni i rzucania itemami (Sklepy, NPC).
@export var pacifist_zone: bool = false


@export_group("Efekty Środowiskowe (Hazards)")
## Wymaga systemu świateł 2D. Jeśli włączone, pokój nakłada na siebie Mroczną Maskę wymuszając na graczu użycie latarki.
@export var is_dark_room: bool = false

## AURA (Znika po wyjściu): Efekty aktywne TYLKO w tym pokoju (np. Spowolnienie od błota). Trwają w nieskończoność, dopóki gracz tu jest.
@export var ambient_aura_effects: Array[Effect] = []

## KLĄTWA (Zostaje po wyjściu): Efekty nakładane przy wejściu. Mają swój standardowy czas trwania i znikną same, nawet po zmianie pokoju (np. Trucizna, Krwawienie).
@export var sticky_entry_effects: Array[Effect] = []




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

# Sygnał, gdy pokój zostanie oczyszczony
signal room_cleared 
var active_enemies_count : int = 0

@export_group("Auto-Drzwi (Przejścia)")
## Decyduje, czy ten pokój zezwala na wygenerowanie drzwi na danej ścianie.
## Aby przejście powstało, OBA sąsiadujące pokoje muszą mieć tę flagę włączoną na styku.
@export var allow_door_up: bool = true
@export var allow_door_down: bool = true
@export var allow_door_left: bool = true
@export var allow_door_right: bool = true

@export_group("Elementy Pokoju")
@onready var tile_map : TileMapLayer = $TileMap
@onready var navigation_region_2d : NavigationRegion2D = $NavigationRegion2D
@export var spawn_points : Array[Marker2D] = []

var size_px : Vector2

func _ready() -> void:
	# Jeżeli Mroczny pokój (Ciemność)
	if is_dark_room:
		var darkness = CanvasModulate.new()
		# Ustawiamy kolor na bardzo ciemny granat/szary (zmodyfikuj według uznania)
		darkness.color = Color(0.09, 0.09, 0.09, 1.0) 
		add_child(darkness)
	
	# Ta linijka sprawia, że gra po uruchomieniu zbuduje kafelki i zespawnuje drzwi!
	generate_room()
	
	# Automatyczne pobieranie drzwi przy starcie sceny
	# Ignorujemy działanie w edytorze, jeśli nie jest nam tam potrzebne do logiki
	if not Engine.is_editor_hint():
		_auto_fetch_doors()
		_auto_fetch_spawn_points()

## Główna funkcja wywoływana do zebrania drzwi
func _auto_fetch_doors() -> void:
	doors.clear() # Czyścimy listę dla pewności
	_find_doors_recursive(self) # Zaczynamy szukać od samego pokoju (self)
	print("Pokój " + name + " znalazł automatycznie " + str(doors.size()) + " drzwi.")

## Rekurencyjne szukanie (znajdzie drzwi nawet jeśli są zgrupowane w innym Node2D)
func _find_doors_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Door:
			# Zaleźliśmy obiekt klasy Door! Dodajemy do listy.
			doors.append(child)
		
		# Niezależnie od tego, czy to drzwi czy nie, szukamy też w dzieciach tego węzła.
		# Pozwala to trzymać drzwi w "folderach" np. Node2D o nazwie "Doors".
		if child.get_child_count() > 0:
			_find_doors_recursive(child)

## Automatycznie szuka wewnątrz pokoju węzłów typu Marker2D przypisanych do grupy "RespawnPoint"
func _auto_fetch_spawn_points() -> void:
	spawn_points.clear()
	_find_spawn_points_recursive(self)
	print("Pokój " + name + " znalazł automatycznie " + str(spawn_points.size()) + " punktów respawnu z grupy.")

## Rekurencyjne przeszukiwanie drzewa węzłów pokoju
func _find_spawn_points_recursive(node: Node) -> void:
	for child in node.get_children():
		# Sprawdzamy czy to Marker2D oraz czy należy do grupy RespawnPoint
		if child is Marker2D and child.is_in_group("RespawnPoint"):
			spawn_points.append(child)
		
		# Jeśli węzeł ma własne dzieci, szukamy głębiej
		if child.get_child_count() > 0:
			_find_spawn_points_recursive(child)

## Generowanie pokoju
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

## Pozwala sprawdzić, czy na tej ścianie postawiłeś już drzwi ręcznie w edytorze
func get_door(dir: Door.Direction) -> Door:
	for d in doors:
		if d.door_direction == dir:
			return d
	return null

## Wstawia obiekt drzwi w idealnym fizycznym środku ściany (ZWRACA TEN OBIEKT!)
func spawn_auto_door(dir: Door.Direction, door_scene: PackedScene) -> Door:
	# Zabezpieczenie: Jeśli drzwi już tu są, po prostu je zwracamy
	var existing_door = get_door(dir)
	if existing_door != null:
		return existing_door

	if not tile_map or not tile_map.tile_set:
		return null

	var tile_size = tile_map.tile_set.tile_size
	
	# Liczymy całkowity rozmiar pokoju w PIKSELACH
	var room_width_px = float(room_size_tiles.x * tile_size.x)
	var room_height_px = float(room_size_tiles.y * tile_size.y)
	
	var exact_pos = Vector2.ZERO

	# Wyliczamy pikselowy środek dla każdej krawędzi (z uwzględnieniem połowy kafelka na grubość ściany)
	match dir:
		Door.Direction.UP:
			exact_pos = Vector2(room_width_px / 2.0, float(tile_size.y) / 2.0)
		Door.Direction.DOWN:
			exact_pos = Vector2(room_width_px / 2.0, room_height_px - (float(tile_size.y) / 2.0))
		Door.Direction.LEFT:
			exact_pos = Vector2(float(tile_size.x) / 2.0, room_height_px / 2.0)
		Door.Direction.RIGHT:
			exact_pos = Vector2(room_width_px - (float(tile_size.x) / 2.0), room_height_px / 2.0)

	var new_door = door_scene.instantiate() as Door
	new_door.door_direction = dir
	
	# Automatyczny obrót drzwi względem ściany
	match dir:
		Door.Direction.UP:
			new_door.rotation_degrees = 0
		Door.Direction.DOWN:
			new_door.rotation_degrees = 180
		Door.Direction.LEFT:
			new_door.rotation_degrees = -90
		Door.Direction.RIGHT:
			new_door.rotation_degrees = 90
	
	# Bezpośrednie przypisanie dokładnej fizycznej pozycji
	new_door.position = exact_pos
	
	add_child(new_door)
	doors.append(new_door)
	
	return new_door

## Akutalizacja regionu nawigacji
func update_navigation_region() -> void:
	if not navigation_region_2d or not tile_map or not tile_map.tile_set: return
	var tile_size = tile_map.tile_set.tile_size
	var nav_poly = NavigationPolygon.new()
	
	# Definiujemy wierzchołki naszego prostokątnego pokoju
	var points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(room_size_tiles.x * tile_size.x, 0),
		Vector2(room_size_tiles.x * tile_size.x, room_size_tiles.y * tile_size.y),
		Vector2(0, room_size_tiles.y * tile_size.y)
	])
	
	# Zamiast przestarzałego 'outlines', przypisujemy wierzchołki bezpośrednio:
	nav_poly.vertices = points
	
	# Tworzymy z nich jeden wielki poligon, łącząc wierzchołki (indeksy: 0, 1, 2, 3)
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	
	navigation_region_2d.navigation_polygon = nav_poly

## Wyliczanie granic pokoju
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

#region Logika stanu walki

## Sprawdza, czy w pokoju są wrogowie i odpowiednio zarządza drzwiami
func check_and_lock_room() -> void:
	# 1. Strefa Bezpieczna (Sklep, Dev Room) - Ignoruje zamykanie
	if ignore_combat_lock:
		for door in doors:
			door.unlock_door()
		return
		
	# 2. Klatka / Arena - Zamyka się natychmiast, ignoruje liczenie wrogów!
	if lock_permanently_after_entry:
		print("Pułapka! Zamykam drzwi na stałe w pokoju: " + name)
		for door in doors:
			door.lock_door()
		return

	# 3. Standardowa walka - Zamyka tylko, jeśli wykryje wrogów
	active_enemies_count = 0
	_find_enemies_recursive(self)
	
	if active_enemies_count > 0:
		print("Wrogowie wykryci! Liczba: " + str(active_enemies_count) + ". Zamykam drzwi w pokoju: " + name)
		for door in doors:
			door.lock_door()
	else:
		for door in doors:
			door.unlock_door()

## Szuka rekurencyjnie przeciwników pośród wszystkich dzieci pokoju
func _find_enemies_recursive(node: Node) -> void:
	for child in node.get_children():
		# Zakładamy, że przeciwnicy znajdują się w grupie "Enemy"
		if child.is_in_group(ENEMY_GROUP):
			active_enemies_count += 1
			
			# Nasłuchujemy, kiedy przeciwnik zniknie (zginie)
			if not child.tree_exited.is_connected(_on_enemy_died):
				child.tree_exited.connect(_on_enemy_died)
				
		if child.get_child_count() > 0:
			_find_enemies_recursive(child)

## Reaguje na śmierć (usunięcie) przeciwnika
func _on_enemy_died() -> void:
	active_enemies_count -= 1
	if active_enemies_count <= 0:
		room_cleared.emit()
		
		# Klatka nie otwiera drzwi po czyszczeniu!
		if lock_permanently_after_entry:
			print("Pokój oczyszczony, ale to pułapka! Drzwi pozostają zamknięte.")
		else:
			print("Pokój oczyszczony! Odblokowuję drzwi.")
			for door in doors:
				door.unlock_door()

#endregion
