extends Node
## Klasa poziomu, przechowywująca pokoje na poziomie
class_name Map

# --- STAŁE (Wyeliminowanie magicznych stringów) ---
## Grupa gracza
const PLAYER_GROUP = "Player"

## Sygnał zmiany pokoju
signal room_changed(new_room: Room)

## Sygnał aktualizacji mapy (UI)
signal map_updated()

@export_group("Główne Obiekty")
## Pokój startowy
@export var starting_room: Room


@export_group("Ustawienia Respawnu")
## Czy po respawnie wyczyścić historię odkrytych i odwiedzonych pokoi na minimapie?
@export var reset_map_history_on_respawn: bool = true

## Czy całkowicie zresetować poziom (przeładować aktualną scenę gry)?
## UWAGA: Przeładowanie sceny zresetuje też statystyki/ekwipunek gracza do wartości początkowych.
@export var reload_entire_scene_on_respawn: bool = false

## Obecny pokój na scenie
var current_room: Room
## Wszystkie pokoje
var all_rooms: Array[Room] = []
## Odkryte pokoje (widoczne na mapie)
var discovered_rooms: Array[Room] = []
## Pokoje odwiedzone
var visited_rooms: Array[Room] = []

# Słownik przestrzenny (Grid)
## Kluczem jest Vector2i (np. Vector2i(0,0)), a wartością obiekt Room
var room_grid: Dictionary = {}

@export_group("Generacja Drzwi")
## Scena drzwi, która ma być automatycznie wstawiana do pokoi
@export var auto_door_scene: PackedScene

func _ready() -> void:
	# Rejestracja i ustawianie pokoi
	for child in get_children():
		if child is Room:
			register_room(child)
			if child != starting_room :
				remove_child(child)
	
	# 1. NAJPIERW z centralnego poziomu spawnujemy fizyczne drzwi tam, gdzie oba pokoje się zgadzają
	_auto_spawn_missing_doors()
	# 2. POTEM Auto-Linker zszywa wszystkie drzwi (te wstawione ręcznie i te wstawione przez automat)
	_auto_link_doors()
	
	# Wejście do pokoju startowego
	if starting_room:
		change_room(starting_room)

# --- FUNKCJE DYNAMIKI MAPY ---

## Rejestracja pokoju, przypisuje go do list pokoi i aktualizuje mapę
func register_room(room: Room) -> void:
	if not all_rooms.has(room):
		all_rooms.append(room)
		
		# Zapisujemy pokój w siatce (Grid)
		# Używamy zmiennej map_position z room.gd jako klucza
		room_grid[room.map_position] = room
		
		map_updated.emit()

## Funkcja do dynamicznego usuwania pokoju (np. pokój się zapadł/zniszczył)
func unregister_room(room: Room) -> void:
	if all_rooms.has(room):
		all_rooms.append(room)
		all_rooms.erase(room)
	
	if discovered_rooms.has(room):
		discovered_rooms.erase(room)
		
	# Usunięcie z listy odwiedzonych przy kasowaniu pokoju
	if visited_rooms.has(room):
		visited_rooms.erase(room)
	
	# Usuwamy pokój z siatki
	if room_grid.has(room.map_position) and room_grid[room.map_position] == room:
		room_grid.erase(room.map_position)
	
	map_updated.emit() # Informujemy UI o zmianie

## Odwiedzenie pokoju (dodaje do listy odwiedzonych)
func discover_room(room: Room) -> void:
	if not discovered_rooms.has(room):
		discovered_rooms.append(room)
		map_updated.emit() # Odświeżamy mapę po odkryciu

## Zwraca pokój w którym znajdują się drzwi
func find_room_by_door(target_door: Door) -> Room:
	for room in all_rooms:
		# Sprawdzamy czy te konkretne drzwi należą do tego pokoju
		# Nawet jeśli pokój jest poza drzewem sceny, ta funkcja zadziała
		if room.is_ancestor_of(target_door):
			return room
	return null

## Odkrywa wszystkie pokoje sąsiadujące z podanym pokojem (poprzez połączone drzwi)
func _discover_neighboring_rooms(room: Room) -> void:
	for door in room.doors:
		if door.destination_door:
			# Szukamy pokoju, w którym znajdują się drzwi docelowe
			var neighbor_room = find_room_by_door(door.destination_door)
			# Sprawdzamy, czy pokój istnieje i CZY NIE JEST oznaczony jako sekretny
			if neighbor_room and not neighbor_room.is_secret:
				discover_room(neighbor_room) # Odkrywamy go na mapie

## Funkcja zmiany pokoju
func change_room(new_room: Room, target_door: Door = null) -> void:
	# 1. NAJPIERW ŁAPIEMY GRACZA! Zanim cokolwiek usuniemy.
	var player = get_player()
	
	# Zabezpieczamy gracza: wyciągamy go ze starego pokoju, żeby nie zniknął razem z nim
	if player and player.get_parent():
		player.get_parent().remove_child(player)

	# 2. Teraz możemy bezpiecznie usunąć stary pokój
	if current_room:
		_disconnect_door_signals(current_room)
		if current_room.is_inside_tree():
			remove_child(current_room)
		
	# 3. Dodajemy nowy pokój
	current_room = new_room
	current_room.visible = true
	
	if not current_room.is_inside_tree():
		add_child(current_room)
		
	_connect_door_signals(current_room)
	discover_room(current_room)
	_discover_neighboring_rooms(current_room)
	
	if not visited_rooms.has(current_room):
		visited_rooms.append(current_room)
	
	room_changed.emit(current_room)
	
	# 4. UMIESZCZAMY GRACZA W NOWYM POKOJU
	if player:
		# Ustawianie entity spawn signal
		if not player.entity_spawn_requested.is_connected(_on_entity_spawn_requested):
			player.entity_spawn_requested.connect(_on_entity_spawn_requested)
		
		# Ustawianie pozycji spawnpointem
		if target_door and target_door.spawn_point:
			player.global_position = target_door.spawn_point.global_position
			
		# Szukamy węzła Y-Sort
		var target_parent = current_room.find_child("Entities")
		if not target_parent:
			target_parent = current_room
			
		# Ponieważ gracz nie ma teraz rodzica (wyciągnęliśmy go na samej górze), po prostu go dodajemy:
		target_parent.add_child(player)
		
	# 5. Odpalamy logikę walki / blokady pokoju po wejściu gracza
	current_room.check_and_lock_room()

## Obsługa spawnowania gracza z sygnału
func _on_entity_spawn_requested(spawned_node: Node2D, spawn_pos: Vector2) -> void:
	if current_room:
		current_room.add_child(spawned_node)
	else:
		# Awaryjne dodanie bezpośrednio do sceny, jeśli nie ma aktywnego pokoju
		get_tree().current_scene.add_child(spawned_node)
		
	# Pozycję ustalamy ZAWSZE po dodaniu obiektu do drzewa!
	spawned_node.global_position = spawn_pos

## Podłączenie sygnału do drzwi
func _connect_door_signals(room: Room) -> void:
	# Room sam pobiera swoje drzwi w _ready lub auto_fetch
	for door in room.doors:
		if not door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.connect(_on_door_entered)

## Odłączenie sygnału od drzwi
func _disconnect_door_signals(room: Room) -> void:
	for door in room.doors:
		if door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.disconnect(_on_door_entered)

## Obługa sygnału wejścia w drzwi
func _on_door_entered(door: Door) -> void:
	# Sprawdzamy, czy te drzwi w ogóle gdzieś prowadzą
	if door.destination_door:
		# Używamy naszej nowej funkcji przeszukującej listę all_rooms
		var next_room = find_room_by_door(door.destination_door)
		
		if next_room:
			call_deferred("change_room", next_room, door.destination_door)
		else:
			push_warning("Map: Drzwi docelowe nie znajdują się w żadnym węźle Room!")
	else:
		push_warning("Map: Gracz wszedł w drzwi, ale nie przypisano im destination_door w edytorze.")

## Funkcja wywoływana, gdy gracz zostanie zrespawnowany
func handle_player_respawn(player: PlayerCharacter) -> void:
	# OPCJA 1: Pełny, twardy reset (Najwygodniejszy dla gier typu Roguelike)
	if reload_entire_scene_on_respawn:
		print("Menedżer Mapy: Włączony pełny reset. Przeładowuję aktualną scenę gry...")
		get_tree().reload_current_scene()
		return # Kod poniżej się nie wykona, ponieważ gra buduje się na nowo od zera
	
	# OPCJA 2: Miękki reset (Gracz zachowuje swój obiekt, np. zdobyty ekwipunek w inventory)
	if starting_room:
		# Przenosimy gracza z powrotem do pokoju startowego za pomocą istniejącej logiki
		change_room(starting_room)
		
		# Pozycjonowanie gracza w pokoju
		if starting_room.spawn_points.size() > 0:
			player.global_position = starting_room.spawn_points[0].global_position
			print("Menedżer Mapy: Gracz zrespawnował się w punkcie 'spawn_points' pokoju startowego.")
		else:
			var room_center_offset = starting_room.size_px / 2.0
			player.global_position = starting_room.global_position + room_center_offset
			push_warning("Menedżer Mapy: Pokój startowy nie ma zdefiniowanych spawn_points. Użyto środka pokoju.")
		
		# Obsługa flagi historii mapy (odkryte/odwiedzone pokoje)
		if reset_map_history_on_respawn:
			discovered_rooms.clear()
			visited_rooms.clear()
			discover_room(starting_room)
			print("Menedżer Mapy: Wyczyszczono historię minimapy (Reset historii pokoi).")
		else:
			print("Menedżer Mapy: Zachowano historię minimapy.")
			# Upewniamy się tylko, że pokój startowy jest oznaczony jako odkryty i odwiedzony
			discover_room(starting_room)
			
		map_updated.emit()
	else:
		push_warning("Menedżer Mapy: Brak zdefiniowanego starting_room dla respawnu.")

## Zwrócenie gracza ze sceny
func get_player() -> PlayerCharacter :
	return get_tree().get_first_node_in_group(PLAYER_GROUP)

# Odpala się automatycznie, gdy węzeł jest na stałe usuwany z gry (np. przy zamykaniu okna)
func _exit_tree() -> void:
	for room in all_rooms:
		# Jeśli pokój wciąż istnieje w pamięci, ale nie ma go na mapie (jest sierotą), 
		# musimy go ręcznie zniszczyć, aby nie wyciekł:
		if is_instance_valid(room) and not room.is_inside_tree():
			room.queue_free()

## Funkcja do sprawdzania co leży na danym polu
## Zwraca pokój znajdujący się na podanych koordynatach siatki (lub null, jeśli pole jest puste)
func get_room_at(coords: Vector2i) -> Room:
	if room_grid.has(coords):
		return room_grid[coords]
	return null

## Centralny system generowania drzwi. 
func _auto_spawn_missing_doors() -> void:
	if auto_door_scene == null:
		return
	
	# Przeszukujemy każdy pokój na wirtualnej siatce
	for coords in room_grid.keys():
		var grid_room = room_grid[coords]
		
		# KRAWĘDŹ 1: Sprawdzamy sąsiada po PRAWEJ (X+1, Y)
		var right_coords = coords + Vector2i(1, 0)
		if room_grid.has(right_coords):
			var right_room = room_grid[right_coords]
			if grid_room.allow_door_right and right_room.allow_door_left:
				_sync_door_pair(grid_room, Door.Direction.RIGHT, right_room, Door.Direction.LEFT)
				
		# KRAWĘDŹ 2: Sprawdzamy sąsiada W DÓŁ (X, Y+1)
		var down_coords = coords + Vector2i(0, 1)
		if room_grid.has(down_coords):
			var down_room = room_grid[down_coords]
			if grid_room.allow_door_down and down_room.allow_door_up:
				_sync_door_pair(grid_room, Door.Direction.DOWN, down_room, Door.Direction.UP)


## Inteligentne parowanie i kopiowanie tekstur z węzła Sprite2D
func _sync_door_pair(room_a: Room, dir_a: Door.Direction, room_b: Room, dir_b: Door.Direction) -> void:
	# Sprawdzamy, czy w edytorze postawiłeś w którychś pokojach drzwi ręcznie
	var door_a = room_a.get_door(dir_a)
	var door_b = room_b.get_door(dir_b)
	
	# SCENARIUSZ 1: Oba pokoje mają już drzwi postawione przez Ciebie. Ignorujemy.
	if door_a != null and door_b != null:
		return
		
	# SCENARIUSZ 2: Nie ma żadnych drzwi. Spawnujemy dwie sztuki bazowe.
	if door_a == null and door_b == null:
		room_a.spawn_auto_door(dir_a, auto_door_scene)
		room_b.spawn_auto_door(dir_b, auto_door_scene)
		return
		
	# SCENARIUSZ 3: TYLKO Pokój A ma drzwi ręczne (z Twoim własnym Sprite'em).
	if door_a != null and door_b == null:
		door_b = room_b.spawn_auto_door(dir_b, auto_door_scene)
		_copy_sprite_texture(door_a, door_b)
		
	# SCENARIUSZ 4: TYLKO Pokój B ma drzwi ręczne (z Twoim własnym Sprite'em).
	elif door_b != null and door_a == null:
		door_a = room_a.spawn_auto_door(dir_a, auto_door_scene)
		_copy_sprite_texture(door_b, door_a)

## Niezwykle wydajne operowanie na wskaźnikach pamięci tekstur
func _copy_sprite_texture(source_door: Door, target_door: Door) -> void:
	# Wyciągamy węzły Sprite2D z instancji (funkcja .instantiate() już je wygenerowała w pamięci)
	var source_sprite = source_door.get_node_or_null("Sprite2D")
	var target_sprite = target_door.get_node_or_null("Sprite2D")
	
	# Bezpośrednie przekazanie wskaźnika. Zero obciążenia dla pamięci!
	if source_sprite and target_sprite:
		target_sprite.texture = source_sprite.texture

## Skrypt Hybrydowy do automatycznego parowania drzwi
func _auto_link_doors() -> void:
	for room in all_rooms:
		for door in room.doors:
			# 1. HYBRYDA: Jeśli drzwi zostały połączone ręcznie przez Ciebie w Inspektorze, ignorujemy je
			if door.destination_door != null:
				continue
				
			# 2. Sprawdzamy kierunek drzwi
			var offset = door.get_direction_offset()
			if offset == Vector2i.ZERO:
				continue # Jeśli zapomniałeś ustawić kierunek, pomijamy te drzwi
				
			# 3. Szukamy sąsiada na siatce względem naszego obecnego pokoju
			var target_coords = room.map_position + offset
			var neighbor_room = get_room_at(target_coords)
			
			if neighbor_room:
				# 4. Szukamy drzwi u sąsiada, które patrzą DOKŁADNIE w naszą stronę (wektor przeciwny)
				var opposite_offset = -offset
				for neighbor_door in neighbor_room.doors:
					
					# Jeśli znajdziemy pasujące wolne drzwi...
					if neighbor_door.destination_door == null and neighbor_door.get_direction_offset() == opposite_offset:
						
						# 5. ŁĄCZYMY DRZWI ZE SOBĄ Z OBU STRON!
						door.destination_door = neighbor_door
						neighbor_door.destination_door = door
						
						print("Map: Zszyto automatycznie drzwi między [" + room.name + "] a [" + neighbor_room.name + "]")
						break
