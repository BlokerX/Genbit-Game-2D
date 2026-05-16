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

## Obecny pokój na scenie
var current_room: Room
## Wszystkie pokoje
var all_rooms: Array[Room] = []
## Odkryte pokoje (widoczne na mapie)
var discovered_rooms: Array[Room] = []
## Pokoje odwiedzone
var visited_rooms: Array[Room] = []

func _ready() -> void:
	# Rejestracja i ustawianie pokoi
	for child in get_children():
		if child is Room:
			register_room(child)
			if child != starting_room :
				remove_child(child)
	
	# Wejście do pokoju startowego
	if starting_room:
		change_room(starting_room)

# --- FUNKCJE DYNAMIKI MAPY ---

## Rejestracja pokoju, przypisuje go do list pokoi i aktualizuje mapę
func register_room(room: Room) -> void:
	if not all_rooms.has(room):
		all_rooms.append(room)
			
		map_updated.emit()

## Funkcja do dynamicznego usuwania pokoju (np. pokój się zapadł/zniszczył)
func unregister_room(room: Room) -> void:
	if all_rooms.has(room):
		all_rooms.erase(room)
	if discovered_rooms.has(room):
		discovered_rooms.erase(room)
		
	# Usunięcie z listy odwiedzonych przy kasowaniu pokoju
	if visited_rooms.has(room):
		visited_rooms.erase(room)
		
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
