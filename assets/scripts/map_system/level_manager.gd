extends Node
class_name LevelManager

@export_group("Główne Obiekty")
@export var starting_room: Room

var current_room: Room
var all_rooms: Array[Room] = []

func _ready() -> void:
	# 1. Zbieramy pokoje
	for child in get_children():
		if child is Room:
			all_rooms.append(child)
			remove_child(child) 
			
	if starting_room:
		change_room(starting_room) 
	else:
		push_warning("LevelManager: Nie przypisano starting_room!")

func change_room(new_room: Room, target_door: Door = null) -> void:
	# 1. Deaktywacja obecnego pokoju
	if current_room:
		_disconnect_door_signals(current_room)
		if current_room.is_inside_tree():
			remove_child(current_room) 
		
	# 2. Aktywacja nowego pokoju
	current_room = new_room
	
	if not current_room.is_inside_tree():
		add_child(current_room)
		
	_connect_door_signals(current_room)
	
	# --- NOWA LOGIKA: Dynamiczne szukanie gracza ---
	# Szukamy w drzewie sceny pierwszego węzła, który należy do grupy "Player"
	var player = get_tree().get_first_node_in_group("Player")
	
	if player:
		if target_door and target_door.spawn_point:
			player.global_position = target_door.spawn_point.global_position
		elif current_room.spawn_points.size() > 0:
			player.global_position = current_room.spawn_points[0].global_position
	else:
		# Jeśli zapomnisz dodać gracza do grupy, menedżer Cię o tym poinformuje
		push_warning("LevelManager: Nie znaleziono gracza! Upewnij się, że Twój gracz jest w grupie 'Player'.")

func _connect_door_signals(room: Room) -> void:
	for node in room.doors:
		var door = node as Door
		if door and not door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.connect(_on_door_entered)

func _disconnect_door_signals(room: Room) -> void:
	for node in room.doors:
		var door = node as Door
		if door and door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.disconnect(_on_door_entered)

func _on_door_entered(door: Door) -> void:
	var next_room = door.destination_room
	if next_room:
		call_deferred("change_room", next_room, door.teleport_door)
