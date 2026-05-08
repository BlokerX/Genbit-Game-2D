extends Node
class_name LevelManager

signal room_changed(new_room: Room)
signal map_updated() # Nowy uniwersalny sygnał zmiany na mapie

@export_group("Główne Obiekty")
@export var starting_room: Room

var current_room: Room
var all_rooms: Array[Room] = []
var discovered_rooms: Array[Room] = [] # Pokoje widoczne na mapie
var visited_rooms: Array[Room] = []    # Pokoje, w których gracz już był

func _ready() -> void:
	for child in get_children():
		if child is Room:
			register_room(child) # Używamy nowej funkcji do rejestracji
			remove_child(child) 
			
	if starting_room:
		change_room(starting_room)

# --- FUNKCJE DYNAMIKI MAPY ---

func register_room(room: Room) -> void:
	if not all_rooms.has(room):
		all_rooms.append(room)
		
		# Logika autoodkrywania: jeśli to NIE jest sekret, dodaj do widocznych
		if not room.is_secret:
			discovered_rooms.append(room)
			
		map_updated.emit()

## Funkcja do dynamicznego usuwania pokoju (np. pokój się zapadł/zniszczył)
func unregister_room(room: Room) -> void:
	if all_rooms.has(room):
		all_rooms.erase(room)
	if discovered_rooms.has(room):
		discovered_rooms.erase(room)
		
	# --- POPRAWKA: Usunięcie z listy odwiedzonych przy kasowaniu pokoju ---
	if visited_rooms.has(room):
		visited_rooms.erase(room)
		
	map_updated.emit() # Informujemy UI o zmianie

func discover_room(room: Room) -> void:
	if not discovered_rooms.has(room):
		discovered_rooms.append(room)
		map_updated.emit() # Odświeżamy mapę po odkryciu

func find_room_by_door(target_door: Door) -> Room:
	for room in all_rooms:
		# Sprawdzamy czy te konkretne drzwi należą do tego pokoju
		# Nawet jeśli pokój jest poza drzewem sceny, ta funkcja zadziała
		if room.is_ancestor_of(target_door):
			return room
	return null

func change_room(new_room: Room, target_door: Door = null) -> void:
	if current_room:
		_disconnect_door_signals(current_room)
		if current_room.is_inside_tree():
			remove_child(current_room)
		
	current_room = new_room
	
	if not current_room.is_inside_tree():
		add_child(current_room)
		
	_connect_door_signals(current_room)
	
	# Zaznaczamy pokój jako odkryty (to odświeży mapę)
	discover_room(current_room)
	
	# Dodajemy pokój do listy ODWWIEDZONYCH
	if not visited_rooms.has(current_room):
		visited_rooms.append(current_room)
	
	room_changed.emit(current_room)
	
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		if target_door and target_door.spawn_point:
			player.global_position = target_door.spawn_point.global_position
		elif current_room.spawn_points.size() > 0:
			player.global_position = current_room.spawn_points[0].global_position

# --- Sygnały drzwi (podłączanie/odłączanie) ---
func _connect_door_signals(room: Room) -> void:
	# Room sam pobiera swoje drzwi w _ready lub auto_fetch
	for door in room.doors:
		if not door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.connect(_on_door_entered)

func _disconnect_door_signals(room: Room) -> void:
	for door in room.doors:
		if door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.disconnect(_on_door_entered)

func _on_door_entered(door: Door) -> void:
	# Sprawdzamy, czy te drzwi w ogóle gdzieś prowadzą
	if door.destination_door:
		# Używamy naszej nowej funkcji przeszukującej listę all_rooms
		var next_room = find_room_by_door(door.destination_door)
		
		if next_room:
			call_deferred("change_room", next_room, door.destination_door)
		else:
			push_warning("LevelManager: Drzwi docelowe nie znajdują się w żadnym węźle Room!")
	else:
		push_warning("LevelManager: Gracz wszedł w drzwi, ale nie przypisano im destination_door w edytorze.")
