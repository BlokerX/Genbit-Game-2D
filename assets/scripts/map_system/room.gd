@tool
extends Node2D
## Pokój
class_name Room

const ENEMY_GROUP = "Enemy"
const ITEM_PICKUP_SCENE = preload("res://assets/scenes/item_pickup.tscn")

@export_group("Mapa")
## Pozycja pokoju na siatce minimapy (np. 0,0 to start, 1,0 to pokój po prawej)
@export var map_position : Vector2i = Vector2i.ZERO

enum TransitionMode { FADE, SLIDE, BOTH }

@export_group("Ustawienia Przejścia")
## Definiuje, w jaki sposób kamera i ekran zachowają się przy wchodzeniu do TEGO pokoju.
@export var transition_mode: TransitionMode = TransitionMode.SLIDE

@export_group("Typ i Znaczenie Pokoju")

enum RoomType { NORMAL, START, TREASURE, SHOP, BOSS, OPEN_WORLD, DEV_ROOM, ARENA }

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

@export_group("Oświetlenie Pokoju (Live Preview)")
## Jeśli włączone, pokój nakłada na siebie Mroczną Maskę.
@export var is_dark_room: bool = false:
	set(value):
		is_dark_room = value
		_update_lighting()

## Kolor mroku (domyślnie bardzo ciemny szary).
@export var darkness_color: Color = Color(0.09, 0.09, 0.09, 1.0):
	set(value):
		darkness_color = value
		_update_lighting()

## Jeśli włączone, gra automatycznie wstawi światło na idealnym środku pokoju.
@export var has_center_light: bool = false:
	set(value):
		has_center_light = value
		_update_lighting()

## Przeciągnij tutaj swoją scenę światła (np. room_light.tscn)
@export var light_scene: PackedScene:
	set(value):
		light_scene = value
		_update_lighting()

## Moc/Jasność (Energy) wygenerowanego światła.
@export_range(0.0, 5.0) var center_light_energy: float = 1.2:
	set(value):
		center_light_energy = value
		_update_lighting()

## Skala (zasięg) wygenerowanego światła.
@export_range(0.1, 10.0) var center_light_scale: float = 1.5:
	set(value):
		center_light_scale = value
		_update_lighting()

@export_group("Efekty Środowiskowe (Hazards)")

## AURA (Znika po wyjściu): Efekty aktywne TYLKO w tym pokoju (np. Spowolnienie od błota). Trwają w nieskończoność, dopóki gracz tu jest.
@export var ambient_aura_effects: Array[Effect] = []

## KLĄTWA (Zostaje po wyjściu): Efekty nakładane przy wejściu. Mają swój standardowy czas trwania i znikną same, nawet po zmianie pokoju (np. Trucizna, Krwawienie).
@export var sticky_entry_effects: Array[Effect] = []

@export_group("Kamera")
## Jeśli true: Kamera płynnie podąża za graczem, nie wychodząc poza ściany pokoju.
## Jeśli false: Kamera na sztywno blokuje się na środku pokoju (styl The Binding of Isaac).
@export var camera_follows_player: bool = false

@export_group("Generatory Proceduralne (Spawn Pools)")
## Pula przeciwników (Losowana na markerach z grupy 'EnemySpawn')
@export_group("Generatory Proceduralne (Spawn Pools)")
@export var enemy_pool: EnemySpawnPool
@export_range(0.0, 1.0) var enemy_spawn_chance: float = 0.75

@export var object_pool: ObjectSpawnPool
@export_range(0.0, 1.0) var object_spawn_chance: float = 0.50

@export var item_pool: ItemLootPool
@export_range(0.0, 1.0) var item_spawn_chance: float = 0.30

# Markery rozdzielone na kategorie
var enemy_spawns: Array[Marker2D] = []
var object_spawns: Array[Marker2D] = []
var item_spawns: Array[Marker2D] = []
var has_spawned_entities: bool = false


@export_group("Wymiary Pokoju")
@export var room_size_tiles : Vector2i = Vector2i(30, 17):
	set(value):
		value.x = max(3, value.x)
		value.y = max(3, value.y)
		room_size_tiles = value
		generate_room()
		queue_redraw()

@export_group("Ustawienia Generowania")
## Jeśli włączone, skrypt NIE wyczyści i NIE nadpisze Twojej TileMapy. 
## Zamiast tego automatycznie zeskanuje to co narysowałeś, by obliczyć wymiary.
@export var manual_tilemap_override: bool = false:
	set(value):
		manual_tilemap_override = value
		generate_room()
		queue_redraw()
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
## Jeśli wrzucisz tu teksturę, drzwi PROWADZĄCE DO TEGO POKOJU oraz DRZWI W TYM POKOJU
## przyjmą ten wygląd (całkowicie nadpisuje to kolor z RoomType!).
@export var custom_door_texture: Texture2D
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
	# Wymuszamy domyślne, poprawne zachowania dla otwartego świata
	if room_type == RoomType.OPEN_WORLD:
		camera_follows_player = true
		ignore_combat_lock = true
	
	# Budujemy pokój
	generate_room()
	
	# Inicjalizujemy światło i mrok 
	_update_lighting()
	
	if not Engine.is_editor_hint():
		# GRA (RUNTIME) - Pobieramy dane potrzebne do rozgrywki
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

## Automatycznie szuka węzłów Marker2D i dzieli je na kategorie
func _auto_fetch_spawn_points() -> void:
	spawn_points.clear() # Główna lista (dla gracza, jeśli jeszcze z niej korzysta)
	enemy_spawns.clear()
	object_spawns.clear()
	item_spawns.clear()
	
	_find_spawn_points_recursive(self)

## Rekurencyjne przeszukiwanie drzewa węzłów pokoju
func _find_spawn_points_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Marker2D:
			# Segregowanie markerów do Reżysera
			if child.is_in_group("EnemySpawn"):
				enemy_spawns.append(child)
			elif child.is_in_group("ObjectSpawn"):
				object_spawns.append(child)
			elif child.is_in_group("ItemSpawn"):
				item_spawns.append(child)
			# Fallback dla starego systemu respawnu gracza (żeby nic nie popsuć)
			elif child.is_in_group("RespawnPoint"):
				spawn_points.append(child)
				
		if child.get_child_count() > 0:
			_find_spawn_points_recursive(child)

## Generowanie pokoju (Proceduralne LUB Ręczne)
func generate_room() -> void:
	if not tile_map: return
	
	# 1. Rysowanie kafelków
	if not manual_tilemap_override:
		tile_map.clear() # Czyścimy kafelki TYLKO wtedy, gdy generujemy pokój automatycznie!
		for x in range(room_size_tiles.x):
			for y in range(room_size_tiles.y):
				var current_pos = Vector2i(x, y)
				if x == 0 or x == room_size_tiles.x - 1 or y == 0 or y == room_size_tiles.y - 1:
					tile_map.set_cell(current_pos, tile_source_id, wall_atlas_pos, wall_alt_id)
				else:
					tile_map.set_cell(current_pos, tile_source_id, floor_atlas_pos, floor_alt_id)
	
	calculate_room_bounds()
	update_navigation_region()
	_update_lighting()

## Pozwala sprawdzić, czy na tej ścianie postawiłeś już drzwi ręcznie w edytorze
func get_door(dir: Door.Direction) -> Door:
	for d in doors:
		if d.door_direction == dir:
			return d
	return null

## Wstawia obiekt drzwi w idealnym fizycznym środku ściany (ZWRACA TEN OBIEKT!)
func spawn_auto_door(dir: Door.Direction, door_scene: PackedScene, custom_tex: Texture2D = null) -> Door:
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
	
	# Nadajemy teksturę przed wejściem do gry!
	if custom_tex != null:
		new_door.door_texture = custom_tex
	
	add_child(new_door)
	doors.append(new_door)
	
	return new_door

## Akutalizacja regionu nawigacji
func update_navigation_region() -> void:
	if not navigation_region_2d or not tile_map or not tile_map.tile_set: return
	var tile_size = tile_map.tile_set.tile_size
	var nav_poly = NavigationPolygon.new()
	
	# ZAWSZE używamy wymiarów z Inspektora, gwarantując stałą siatkę!
	var points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(room_size_tiles.x * tile_size.x, 0),
		Vector2(room_size_tiles.x * tile_size.x, room_size_tiles.y * tile_size.y),
		Vector2(0, room_size_tiles.y * tile_size.y)
	])
	
	nav_poly.vertices = points
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	navigation_region_2d.navigation_polygon = nav_poly

## Wyliczanie granic pokoju dla kamery
func calculate_room_bounds() -> void:
	if tile_map and tile_map.tile_set:
		var tile_size = tile_map.tile_set.tile_size
		# Kamera sztywno opiera się na wytyczonej przez Ciebie wielkości pokoju
		size_px = Vector2(room_size_tiles.x * tile_size.x, room_size_tiles.y * tile_size.y)

func _draw() -> void:
	if Engine.is_editor_hint() or OS.is_debug_build():
		if tile_map and tile_map.tile_set:
			var tile_size = tile_map.tile_set.tile_size
			
			# Rysuje sztywną, zieloną ramkę na podstawie X i Y z Inspektora.
			# Maluj kafelki wewnątrz niej, a kamera nigdy nie wyjdzie poza obszar!
			var rect = Rect2(Vector2.ZERO, Vector2(room_size_tiles.x * tile_size.x, room_size_tiles.y * tile_size.y))
			draw_rect(rect, Color(0, 1, 0, 0.2), false, 2.0)

## Funkcja zarządzająca dynamicznym oświetleniem w edytorze i grze
func _update_lighting() -> void:
	# Zabezpieczenie przed działaniem, zanim węzeł wejdzie do drzewa
	if not is_inside_tree():
		return

	# --- 1. MROK (CanvasModulate) ---
	var mod_name = "RoomDarkness"
	var darkness = find_child(mod_name, false, false)

	# WZORZEC AAA: Lokalny mrok istnieje TYLKO w edytorze dla podglądu.
	# W samej grze lokalny mrok jest usuwany, bo globalnym steruje map.gd!
	if Engine.is_editor_hint() and is_dark_room:
		if not darkness:
			darkness = CanvasModulate.new()
			darkness.name = mod_name
			add_child(darkness)
		darkness.color = darkness_color
	else:
		if darkness:
			darkness.queue_free()

	# --- 2. ŚWIATŁO (PointLight2D) ---
	var light_name = "CenterRoomLight"
	var light = find_child(light_name, false, false)

	if has_center_light:
		if not light:
			# BEZPIECZNE ŁADOWANIE: Jeśli w Inspektorze jest pusto, bierzemy domyślny plik!
			var scene_to_load = light_scene
			if not scene_to_load:
				scene_to_load = load("res://assets/scenes/room_light.tscn")
				
			if scene_to_load:
				light = scene_to_load.instantiate()
				light.name = light_name
				add_child(light)
		
		# Aktualizacja parametrów światła na żywo
		if light is PointLight2D:
			light.energy = center_light_energy
			light.texture_scale = center_light_scale
		
		# Upewniamy się, że wymiary pokoju są aktualne i centrujemy światło
		calculate_room_bounds()
		light.position = size_px / 2.0
	else:
		if light:
			light.queue_free()

#region Logika stanu walki

## Sprawdza, czy w pokoju są wrogowie, odpala Reżysera i zarządza drzwiami
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
	
	# Reżyser Pokoju (Spawn i Skrzynie)
	if not has_spawned_entities and not pacifist_zone:
		_run_director_spawner()
		_fill_hybrid_containers(self) # Wypełnia RĘCZNE i WYLOSOWANE obiekty!
		has_spawned_entities = true
	
	# 3. Standardowa walka - Zamyka tylko, jeśli wykryje wrogów
	# Zlicza wrogów (ręcznych + tych właśnie zespawnowanych)
	active_enemies_count = 0
	_find_enemies_recursive(self)
	
	if active_enemies_count > 0:
		for door in doors: door.lock_door()
	else:
		for door in doors: door.unlock_door()

#region Reżyser

## Główny Reżyser: Czysto rozdzielone 3 niezależne systemy
func _run_director_spawner() -> void:
	var entities_node = find_child("Entities")
	var parent_node = entities_node if entities_node else self
	
	if enemy_pool != null:
		for marker in enemy_spawns:
			if randf() <= enemy_spawn_chance:
				var scene = enemy_pool.get_random_enemy_scene()
				_instantiate_scene(scene, marker.global_position, parent_node)
				
	if object_pool != null:
		for marker in object_spawns:
			if randf() <= object_spawn_chance:
				var scene = object_pool.get_random_object_scene()
				_instantiate_scene(scene, marker.global_position, parent_node)
				
	# 3. SYSTEM PRZEDMIOTÓW NA ZIEMI (Luzem)
	if item_pool != null:
		for marker in item_spawns:
			if randf() <= item_spawn_chance:
				var entry = item_pool.get_random_entry()
				
				if entry != null and entry.item_data != null:
					var pickup = ITEM_PICKUP_SCENE.instantiate() as ItemPickup
					
					# --- ZMIANA TUTAJ: Używamy nowej fabryki ---
					pickup.item = _create_instance_from_entry(entry)
					
					var random_offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
					_instantiate_node(pickup, marker.global_position + random_offset, parent_node)

## Faza Hybrydowa: KROK 1 (Tworzenie listy lootu) -> KROK 2 (Rozrzucanie po skrzyni)
func _fill_hybrid_containers(node: Node) -> void:
	for child in node.get_children():
		var storage = child.get_node_or_null("StorageComponent")
		
		if storage != null and not child.has_meta("is_filled_by_director"):
			child.set_meta("is_filled_by_director", true) 
			
			if item_pool != null:
				# Ile razy Reżyser zakręci kołem fortuny dla tej skrzyni? (np. 3 razy)
				var rolls_to_make = randi_range(2, 4) 
				
				# === KROK 1: GENEROWANIE PULI PRZEDMIOTÓW ===
				var generated_loot: Array[ItemInstance] = []
				
				for i in range(rolls_to_make):
					var entry = item_pool.get_random_entry()
					if entry != null and entry.item_data != null:
						var duplicated_entries = max(1, randi_range(entry.min_slots, entry.max_slots))
						
						for s in range(duplicated_entries):
							# --- ZMIANA TUTAJ: Używamy nowej fabryki ---
							var item_inst = _create_instance_from_entry(entry)
							generated_loot.append(item_inst)
				
				# Mamy teraz gotową listę lootu! Np: [Miecz, Ciastko, Ciastko, Knife]
				
				# === KROK 2: ROZRZUCANIE PO PUSTYCH SLOTACH ===
				for item_inst in generated_loot:
					# Zbieramy wszystkie puste miejsca w skrzyni dla KAŻDEGO przedmiotu na nowo
					var empty_slot_indexes: Array[int] = []
					for slot_idx in range(storage.slots.size()):
						if storage.slots[slot_idx].is_empty():
							empty_slot_indexes.append(slot_idx)
							
					if not empty_slot_indexes.is_empty():
						# Jeśli są wolne kratki, losujemy jedną z nich!
						var random_slot_idx = empty_slot_indexes.pick_random()
						storage.slots[random_slot_idx].item = item_inst
					else:
						# Fallback (skrzynia pełna) - wrzucamy systemowo (np. spróbuje połączyć stacki)
						if storage.has_method("insert_instance"):
							storage.insert_instance(item_inst)
						
		if child.get_child_count() > 0:
			_fill_hybrid_containers(child)

## Pomocnicze wstawianie PackedScene
func _instantiate_scene(scene: PackedScene, pos: Vector2, parent: Node) -> void:
	if scene == null: return
	var instance = scene.instantiate()
	_instantiate_node(instance, pos, parent)

## Pomocnicze wstawianie fizycznego węzła do świata
func _instantiate_node(instance: Node, pos: Vector2, parent: Node) -> void:
	parent.add_child(instance)
	if "global_position" in instance:
		instance.global_position = pos

## Tworzy fizyczną instancję przedmiotu na podstawie wpisu z puli,
## uwzględniając ilość oraz dwa tryby losowania wytrzymałości.
func _create_instance_from_entry(entry: ItemLootEntry) -> ItemInstance:
	var unique_data = entry.item_data.duplicate(true)
	var amount = randi_range(entry.min_amount, entry.max_amount)
	
	# Tworzymy instancję (konstruktor _init automatycznie ustawi durability na max_durable)
	var instance = ItemInstance.new(unique_data, amount)
	
	# Jeśli wpis wymusza zużycie i przedmiot faktycznie może się zepsuć
	if entry.randomize_durability and unique_data.max_durable > 0:
		var new_durability: int = unique_data.max_durable
		
		# Sprawdzamy wybrany przez Ciebie w Inspektorze tryb
		if entry.durability_mode == ItemLootEntry.DurabilityRollMode.PERCENTAGE:
			var dur_percent = randf_range(entry.min_durability_percent, entry.max_durability_percent)
			new_durability = int(float(unique_data.max_durable) * dur_percent)
		else:
			# Tryb EXACT_VALUE (Twarde Cyfry)
			new_durability = randi_range(entry.min_exact_durability, entry.max_exact_durability)
		
		# CLAMPI (Zabezpieczenie): 
		# Upewniamy się, że wylosowana wartość nigdy nie spadnie poniżej 1 (żeby przedmiot nie pękł w rękach) 
		# i nigdy nie przekroczy oryginalnego max_durable (żebyś przypadkiem nie stworzył miecza z 999 użyciami, gdy max to 50).
		instance.durability = clampi(new_durability, 1, unique_data.max_durable)
		
	return instance

#endregion

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
